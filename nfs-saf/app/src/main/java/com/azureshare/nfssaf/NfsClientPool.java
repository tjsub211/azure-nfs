package com.azureshare.nfssaf;

import com.emc.ecs.nfsclient.nfs.nfs3.Nfs3;
import com.emc.ecs.nfsclient.rpc.CredentialUnix;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/** 按连接 id 缓存 Nfs3 客户端（nfs-client-java，纯 Java NFSv3）。 */
public class NfsClientPool {

    private static final NfsClientPool INSTANCE = new NfsClientPool();
    public static NfsClientPool get() { return INSTANCE; }

    private final Map<String, Nfs3> clients = new HashMap<>();

    private NfsClientPool() {}

    public synchronized Nfs3 client(NfsConnection conn) throws IOException {
        Nfs3 c = clients.get(conn.id);
        if (c == null) {
            c = new Nfs3(conn.host, conn.exportPath,
                    new CredentialUnix(conn.uid, conn.gid, null), 3);
            clients.put(conn.id, c);
        }
        return c;
    }

    /** 连接出错时丢弃，使下次重连。 */
    public synchronized void invalidate(String connId) {
        clients.remove(connId);
    }
}
