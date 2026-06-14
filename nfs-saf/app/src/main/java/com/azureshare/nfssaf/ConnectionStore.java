package com.azureshare.nfssaf;

import android.content.ContentResolver;
import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.provider.DocumentsContract;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** 用 SharedPreferences 持久化所有 NFS 连接。 */
public class ConnectionStore {
    private static final String PREFS = "nfs_connections";
    private static final String KEY = "list";

    private final Context ctx;

    public ConnectionStore(Context ctx) {
        this.ctx = ctx.getApplicationContext();
    }

    private SharedPreferences prefs() {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public synchronized List<NfsConnection> list() {
        List<NfsConnection> out = new ArrayList<>();
        String raw = prefs().getString(KEY, "[]");
        try {
            JSONArray arr = new JSONArray(raw);
            for (int i = 0; i < arr.length(); i++) {
                out.add(NfsConnection.fromJson(arr.getJSONObject(i)));
            }
        } catch (JSONException ignored) {
        }
        return out;
    }

    public NfsConnection get(String id) {
        if (id == null) return null;
        for (NfsConnection c : list()) {
            if (id.equals(c.id)) return c;
        }
        return null;
    }

    public synchronized void save(NfsConnection conn) {
        List<NfsConnection> all = list();
        boolean replaced = false;
        for (int i = 0; i < all.size(); i++) {
            if (all.get(i).id.equals(conn.id)) {
                all.set(i, conn);
                replaced = true;
                break;
            }
        }
        if (!replaced) all.add(conn);
        persist(all);
    }

    public synchronized void delete(String id) {
        List<NfsConnection> all = list();
        List<NfsConnection> kept = new ArrayList<>();
        for (NfsConnection c : all) {
            if (!c.id.equals(id)) kept.add(c);
        }
        persist(kept);
    }

    private void persist(List<NfsConnection> all) {
        JSONArray arr = new JSONArray();
        for (NfsConnection c : all) arr.put(c.toJson());
        prefs().edit().putString(KEY, arr.toString()).apply();
        notifyRootsChanged();
    }

    public void notifyRootsChanged() {
        try {
            Uri rootsUri = DocumentsContract.buildRootsUri(NfsDocumentsProvider.AUTHORITY);
            ContentResolver cr = ctx.getContentResolver();
            cr.notifyChange(rootsUri, null);
        } catch (Exception ignored) {
        }
    }
}
