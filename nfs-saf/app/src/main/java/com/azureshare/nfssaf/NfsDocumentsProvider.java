package com.azureshare.nfssaf;

import android.database.Cursor;
import android.database.MatrixCursor;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;

import com.emc.ecs.nfsclient.nfs.io.Nfs3File;
import com.emc.ecs.nfsclient.nfs.io.NfsFileInputStream;
import com.emc.ecs.nfsclient.nfs.io.NfsFileOutputStream;
import com.emc.ecs.nfsclient.nfs.nfs3.Nfs3;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.List;

/** 把 NFS 共享暴露为 Android SAF 文档提供者，后端为 nfs-client-java。 */
public class NfsDocumentsProvider extends DocumentsProvider {

    public static final String AUTHORITY = "com.azureshare.nfssaf.documents";
    private static final String SEP = "::";

    private static final String[] DEFAULT_ROOT_PROJECTION = new String[]{
            Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID, Root.COLUMN_TITLE,
            Root.COLUMN_SUMMARY, Root.COLUMN_FLAGS, Root.COLUMN_ICON,
    };
    private static final String[] DEFAULT_DOCUMENT_PROJECTION = new String[]{
            Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE,
            Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED, Document.COLUMN_FLAGS,
    };

    private ConnectionStore store;
    private HandlerThread ioThread;
    private Handler ioHandler;

    @Override
    public boolean onCreate() {
        store = new ConnectionStore(getContext());
        ioThread = new HandlerThread("nfs-io");
        ioThread.start();
        ioHandler = new Handler(ioThread.getLooper());
        return true;
    }

    // ---------- documentId 编解码 ----------

    private static String docId(String connId, String path) {
        return connId + SEP + path;
    }

    private static String connIdOf(String documentId) {
        int i = documentId.indexOf(SEP);
        return i < 0 ? documentId : documentId.substring(0, i);
    }

    private static String pathOf(String documentId) {
        int i = documentId.indexOf(SEP);
        return i < 0 ? "/" : documentId.substring(i + SEP.length());
    }

    private static String join(String parent, String name) {
        if (parent.endsWith("/")) return parent + name;
        return parent + "/" + name;
    }

    private static String baseName(String path) {
        if ("/".equals(path)) return "/";
        String p = path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
        int i = p.lastIndexOf('/');
        return i < 0 ? p : p.substring(i + 1);
    }

    private static String parentPath(String path) {
        String p = path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
        int i = p.lastIndexOf('/');
        return i <= 0 ? "/" : p.substring(0, i);
    }

    private NfsConnection requireConn(String documentId) throws FileNotFoundException {
        NfsConnection c = store.get(connIdOf(documentId));
        if (c == null) throw new FileNotFoundException("no connection for " + documentId);
        return c;
    }

    private Nfs3File file(String documentId) throws IOException {
        NfsConnection conn = requireConn(documentId);
        Nfs3 client = NfsClientPool.get().client(conn);
        return new Nfs3File(client, pathOf(documentId));
    }

    // ---------- Roots ----------

    @Override
    public Cursor queryRoots(String[] projection) {
        MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_ROOT_PROJECTION);
        for (NfsConnection c : store.list()) {
            MatrixCursor.RowBuilder row = result.newRow();
            row.add(Root.COLUMN_ROOT_ID, c.id);
            row.add(Root.COLUMN_DOCUMENT_ID, docId(c.id, "/"));
            row.add(Root.COLUMN_TITLE, c.name);
            row.add(Root.COLUMN_SUMMARY, c.host + ":" + c.exportPath);
            row.add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE | Root.FLAG_SUPPORTS_IS_CHILD);
            row.add(Root.COLUMN_ICON, android.R.drawable.ic_menu_save);
        }
        return result;
    }

    // ---------- Document queries ----------

    @Override
    public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException {
        MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
        try {
            includeFile(result, documentId, file(documentId));
        } catch (IOException e) {
            NfsClientPool.get().invalidate(connIdOf(documentId));
            throw new FileNotFoundException("queryDocument failed: " + e.getMessage());
        }
        return result;
    }

    @Override
    public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder)
            throws FileNotFoundException {
        MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
        try {
            Nfs3File dir = file(parentDocumentId);
            String parentPath = pathOf(parentDocumentId);
            String connId = connIdOf(parentDocumentId);
            List<String> names = dir.list();
            for (String name : names) {
                if (".".equals(name) || "..".equals(name)) continue;
                String childPath = join(parentPath, name);
                try {
                    includeFile(result, docId(connId, childPath), dir.getChildFile(name));
                } catch (IOException ignored) {
                    // 单个条目取属性失败则跳过
                }
            }
        } catch (IOException e) {
            NfsClientPool.get().invalidate(connIdOf(parentDocumentId));
            throw new FileNotFoundException("queryChildDocuments failed: " + e.getMessage());
        }
        return result;
    }

    private void includeFile(MatrixCursor result, String documentId, Nfs3File f) throws IOException {
        String path = pathOf(documentId);
        boolean isDir = f.isDirectory();
        String displayName = "/".equals(path) ? requireConn(documentId).name : baseName(path);

        int flags = 0;
        if (isDir) {
            flags |= Document.FLAG_DIR_SUPPORTS_CREATE;
        } else {
            flags |= Document.FLAG_SUPPORTS_WRITE;
        }
        if (!"/".equals(path)) {
            flags |= Document.FLAG_SUPPORTS_DELETE | Document.FLAG_SUPPORTS_RENAME;
        }

        String mime = isDir ? Document.MIME_TYPE_DIR : mimeOf(displayName);

        MatrixCursor.RowBuilder row = result.newRow();
        row.add(Document.COLUMN_DOCUMENT_ID, documentId);
        row.add(Document.COLUMN_DISPLAY_NAME, displayName);
        row.add(Document.COLUMN_MIME_TYPE, mime);
        row.add(Document.COLUMN_FLAGS, flags);
        if (!isDir) row.add(Document.COLUMN_SIZE, f.length());
        try {
            row.add(Document.COLUMN_LAST_MODIFIED, f.lastModified());
        } catch (IOException ignored) {
        }
    }

    private static String mimeOf(String name) {
        int dot = name.lastIndexOf('.');
        if (dot >= 0 && dot < name.length() - 1) {
            String ext = name.substring(dot + 1).toLowerCase();
            String m = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
            if (m != null) return m;
        }
        return "application/octet-stream";
    }

    @Override
    public boolean isChildDocument(String parentDocumentId, String documentId) {
        if (!connIdOf(parentDocumentId).equals(connIdOf(documentId))) return false;
        String parent = pathOf(parentDocumentId);
        String child = pathOf(documentId);
        if (!parent.endsWith("/")) parent = parent + "/";
        return child.startsWith(parent);
    }

    // ---------- open / read / write ----------

    @Override
    public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal)
            throws FileNotFoundException {
        final boolean writing = mode.contains("w") || mode.contains("a") || mode.contains("t");
        try {
            final NfsConnection conn = requireConn(documentId);
            final String path = pathOf(documentId);
            final File cache = File.createTempFile("nfs", ".tmp", getContext().getCacheDir());

            Nfs3File remote = file(documentId);
            boolean exists = remote.exists();

            if (!writing) {
                // 读：下载到缓存文件，消费者关闭后删除缓存，避免残留
                downloadToCache(remote, cache);
                return ParcelFileDescriptor.open(cache, ParcelFileDescriptor.MODE_READ_ONLY,
                        ioHandler, new ParcelFileDescriptor.OnCloseListener() {
                            @Override
                            public void onClose(IOException e) {
                                cache.delete();
                            }
                        });
            }

            // 写：若是追加/读写且已存在，先取回现有内容
            if (exists && (mode.contains("a") || mode.contains("r"))) {
                downloadToCache(remote, cache);
            }

            int pmode = ParcelFileDescriptor.parseMode(mode);
            final String connId = connIdOf(documentId);
            return ParcelFileDescriptor.open(cache, pmode, ioHandler, new ParcelFileDescriptor.OnCloseListener() {
                @Override
                public void onClose(IOException e) {
                    try {
                        uploadFromCache(conn, path, cache);
                    } catch (IOException ex) {
                        NfsClientPool.get().invalidate(connId);
                    } finally {
                        cache.delete();
                    }
                }
            });
        } catch (IOException e) {
            NfsClientPool.get().invalidate(connIdOf(documentId));
            throw new FileNotFoundException("openDocument failed: " + e.getMessage());
        }
    }

    private void downloadToCache(Nfs3File remote, File cache) throws IOException {
        try (InputStream in = new NfsFileInputStream(remote);
             OutputStream out = new java.io.FileOutputStream(cache)) {
            copy(in, out);
        }
    }

    private void uploadFromCache(NfsConnection conn, String path, File cache) throws IOException {
        Nfs3 client = NfsClientPool.get().client(conn);
        Nfs3File remote = new Nfs3File(client, path);
        try (InputStream in = new java.io.FileInputStream(cache);
             OutputStream out = new NfsFileOutputStream(remote)) {
            copy(in, out);
        }
    }

    private static void copy(InputStream in, OutputStream out) throws IOException {
        byte[] buf = new byte[64 * 1024];
        int n;
        while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
        out.flush();
    }

    // ---------- create / delete / rename ----------

    @Override
    public String createDocument(String parentDocumentId, String mimeType, String displayName)
            throws FileNotFoundException {
        try {
            NfsConnection conn = requireConn(parentDocumentId);
            Nfs3 client = NfsClientPool.get().client(conn);
            String childPath = join(pathOf(parentDocumentId), displayName);
            Nfs3File child = new Nfs3File(client, childPath);
            if (Document.MIME_TYPE_DIR.equals(mimeType)) {
                child.mkdir();
            } else {
                child.createNewFile();
            }
            notifyChildrenChanged(parentDocumentId);
            return docId(conn.id, childPath);
        } catch (IOException e) {
            NfsClientPool.get().invalidate(connIdOf(parentDocumentId));
            throw new FileNotFoundException("createDocument failed: " + e.getMessage());
        }
    }

    @Override
    public void deleteDocument(String documentId) throws FileNotFoundException {
        try {
            file(documentId).delete();
            notifyChildrenChanged(docId(connIdOf(documentId), parentPath(pathOf(documentId))));
        } catch (IOException e) {
            NfsClientPool.get().invalidate(connIdOf(documentId));
            throw new FileNotFoundException("deleteDocument failed: " + e.getMessage());
        }
    }

    @Override
    public String renameDocument(String documentId, String displayName) throws FileNotFoundException {
        try {
            NfsConnection conn = requireConn(documentId);
            Nfs3 client = NfsClientPool.get().client(conn);
            String oldPath = pathOf(documentId);
            String newPath = join(parentPath(oldPath), displayName);
            Nfs3File src = new Nfs3File(client, oldPath);
            Nfs3File dst = new Nfs3File(client, newPath);
            src.renameTo(dst);
            notifyChildrenChanged(docId(conn.id, parentPath(oldPath)));
            return docId(conn.id, newPath);
        } catch (IOException e) {
            NfsClientPool.get().invalidate(connIdOf(documentId));
            throw new FileNotFoundException("renameDocument failed: " + e.getMessage());
        }
    }

    private void notifyChildrenChanged(String parentDocumentId) {
        try {
            android.net.Uri uri = android.provider.DocumentsContract.buildChildDocumentsUri(AUTHORITY, parentDocumentId);
            getContext().getContentResolver().notifyChange(uri, null);
        } catch (Exception ignored) {
        }
    }
}
