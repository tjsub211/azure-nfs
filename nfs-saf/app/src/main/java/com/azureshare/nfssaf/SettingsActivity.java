package com.azureshare.nfssaf;

import android.app.AlertDialog;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.DocumentsContract;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import java.util.List;

public class SettingsActivity extends AppCompatActivity {

    private static final int MENU_ADD = 1;

    private ConnectionStore store;
    private ListView list;
    private TextView empty;
    private List<NfsConnection> data;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);
        store = new ConnectionStore(this);
        list = findViewById(R.id.list);
        empty = findViewById(R.id.empty);

        Button btnOpenFiles = findViewById(R.id.btnOpenFiles);
        btnOpenFiles.setOnClickListener(v -> openInFiles());

        list.setOnItemClickListener((parent, view, position, id) -> openEditor(data.get(position).id));
        list.setOnItemLongClickListener((parent, view, position, id) -> {
            confirmDelete(data.get(position));
            return true;
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        refresh();
    }

    private void refresh() {
        data = store.list();
        String[] rows = new String[data.size()];
        for (int i = 0; i < data.size(); i++) {
            NfsConnection c = data.get(i);
            rows[i] = c.name + "\n" + c.host + ":" + c.exportPath;
        }
        list.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, rows));
        empty.setVisibility(data.isEmpty() ? View.VISIBLE : View.GONE);
    }

    private void openInFiles() {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        // 直接定位到 NFS 共享根，省去在系统文件里翻抽屉的步骤
        List<NfsConnection> conns = store.list();
        if (!conns.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            String rootDocId = conns.get(0).id + "::/";
            Uri initial = DocumentsContract.buildDocumentUri(NfsDocumentsProvider.AUTHORITY, rootDocId);
            i.putExtra(DocumentsContract.EXTRA_INITIAL_URI, initial);
        }
        try {
            startActivity(i);
        } catch (Exception e) {
            Toast.makeText(this, "无法打开系统文件选择器", Toast.LENGTH_SHORT).show();
        }
    }

    private void openEditor(String connId) {
        Intent i = new Intent(this, EditConnectionActivity.class);
        if (connId != null) i.putExtra(EditConnectionActivity.EXTRA_ID, connId);
        startActivity(i);
    }

    private void confirmDelete(NfsConnection c) {
        new AlertDialog.Builder(this)
                .setTitle(c.name)
                .setMessage("删除该连接？")
                .setPositiveButton(R.string.delete, (d, w) -> {
                    store.delete(c.id);
                    NfsClientPool.get().invalidate(c.id);
                    refresh();
                })
                .setNegativeButton(android.R.string.cancel, null)
                .show();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuItem add = menu.add(0, MENU_ADD, 0, R.string.add_connection);
        add.setIcon(android.R.drawable.ic_menu_add);
        add.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        if (item.getItemId() == MENU_ADD) {
            openEditor(null);
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
}
