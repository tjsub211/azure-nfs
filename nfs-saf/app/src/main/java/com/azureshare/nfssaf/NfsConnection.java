package com.azureshare.nfssaf;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.UUID;

/** 一个 NFS 连接的配置（对应 SAF 里的一个 Root）。 */
public class NfsConnection {
    public String id;
    public String name;       // 显示名，如 "AzureShare"
    public String host;       // PC 热点网关 IP
    public String exportPath; // /export/azure-share
    public int uid = 1000;
    public int gid = 1000;

    public NfsConnection() {
        this.id = UUID.randomUUID().toString();
    }

    public JSONObject toJson() {
        JSONObject o = new JSONObject();
        try {
            o.put("id", id);
            o.put("name", name);
            o.put("host", host);
            o.put("exportPath", exportPath);
            o.put("uid", uid);
            o.put("gid", gid);
        } catch (JSONException ignored) {
        }
        return o;
    }

    public static NfsConnection fromJson(JSONObject o) {
        NfsConnection c = new NfsConnection();
        c.id = o.optString("id", c.id);
        c.name = o.optString("name", "NFS");
        c.host = o.optString("host", "");
        c.exportPath = o.optString("exportPath", "/");
        c.uid = o.optInt("uid", 1000);
        c.gid = o.optInt("gid", 1000);
        return c;
    }
}
