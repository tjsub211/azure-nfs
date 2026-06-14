package com.azureshare.nfssaf;

import android.os.Bundle;
import android.text.TextUtils;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

public class EditConnectionActivity extends AppCompatActivity {

    public static final String EXTRA_ID = "connId";

    private ConnectionStore store;
    private NfsConnection editing;
    private EditText name, host, exportPath, uid, gid;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_edit_connection);
        store = new ConnectionStore(this);

        name = findViewById(R.id.name);
        host = findViewById(R.id.host);
        exportPath = findViewById(R.id.exportPath);
        uid = findViewById(R.id.uid);
        gid = findViewById(R.id.gid);

        String id = getIntent().getStringExtra(EXTRA_ID);
        if (id != null) {
            editing = store.get(id);
        }
        if (editing != null) {
            name.setText(editing.name);
            host.setText(editing.host);
            exportPath.setText(editing.exportPath);
            uid.setText(String.valueOf(editing.uid));
            gid.setText(String.valueOf(editing.gid));
        }

        Button save = findViewById(R.id.btnSave);
        save.setOnClickListener(v -> save());
    }

    private void save() {
        String h = host.getText().toString().trim();
        String ep = exportPath.getText().toString().trim();
        if (TextUtils.isEmpty(h) || TextUtils.isEmpty(ep)) {
            Toast.makeText(this, R.string.empty_fields, Toast.LENGTH_SHORT).show();
            return;
        }
        NfsConnection c = editing != null ? editing : new NfsConnection();
        c.name = orDefault(name.getText().toString().trim(), "NFS");
        c.host = h;
        c.exportPath = ep;
        c.uid = parseInt(uid.getText().toString().trim(), 1000);
        c.gid = parseInt(gid.getText().toString().trim(), 1000);
        store.save(c);
        Toast.makeText(this, R.string.save, Toast.LENGTH_SHORT).show();
        finish();
    }

    private static String orDefault(String s, String def) {
        return TextUtils.isEmpty(s) ? def : s;
    }

    private static int parseInt(String s, int def) {
        try {
            return Integer.parseInt(s);
        } catch (NumberFormatException e) {
            return def;
        }
    }
}
