import 'package:flutter/material.dart';

import '../session.dart';
import '../l10n.dart';
import '../widgets/bits.dart';
import 'flows.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const AppText('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const AppText('存储'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StorageScreen(session: session),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const AppText('主题'),
            trailing: DropdownButton<ThemeMode>(
              value: session.themeMode,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: AppText('跟随系统'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: AppText('浅色')),
                DropdownMenuItem(value: ThemeMode.dark, child: AppText('深色')),
              ],
              onChanged: (value) {
                if (value != null) session.setTheme(value);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const AppText('语言'),
            trailing: DropdownButton<String>(
              value: session.language,
              items: const [
                DropdownMenuItem(value: 'system', child: AppText('跟随系统')),
                DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                DropdownMenuItem(value: 'zh-Hant', child: Text('繁體中文')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
              onChanged: (value) {
                if (value != null) session.setLanguage(value);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const AppText('账号安全'),
            subtitle: const AppText('密码、双重验证、删除账号'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(session: session, security: true),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  List<Map<String, dynamic>> configs = [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.session.api.storageConfigs();
      if (mounted) {
        setState(() {
          configs = items;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? config]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorageEditor(session: widget.session, config: config),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('存储'),
      actions: [
        IconButton(
          tooltip: tr(context, '添加存储'),
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: loading
        ? const LoadingPane()
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const ListTile(
                  title: AppText('平台存储'),
                  subtitle: AppText('没有默认自定义存储时使用平台存储'),
                ),
                if (error != null)
                  ListTile(
                    title: Text('$error'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _load,
                    ),
                  ),
                for (final config in configs)
                  ListTile(
                    title: Text('${config['name'] ?? config['bucket']}'),
                    subtitle: Text('${config['endpoint']}'),
                    leading: Icon(
                      config['isDefault'] == true
                          ? Icons.cloud_done
                          : Icons.cloud_outlined,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _edit(config),
                  ),
              ],
            ),
          ),
  );
}

class StorageEditor extends StatefulWidget {
  const StorageEditor({super.key, required this.session, this.config});
  final AppSession session;
  final Map<String, dynamic>? config;
  @override
  State<StorageEditor> createState() => _StorageEditorState();
}

class _StorageEditorState extends State<StorageEditor> {
  final form = GlobalKey<FormState>();
  late final fields = {
    for (final key in [
      'name',
      'endpoint',
      'region',
      'bucket',
      'accessKeyId',
      'secretAccessKey',
    ])
      key: TextEditingController(
        text: key == 'secretAccessKey'
            ? ''
            : '${widget.config?[key] ?? (key == 'region' ? 'auto' : '')}',
      ),
  };
  late bool pathStyle = widget.config?['pathStyle'] == true;
  late bool isDefault = widget.config?['isDefault'] == true;
  late bool enabled = widget.config?['enabled'] != false;
  bool busy = false;
  String status = '';

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get input => {
    if (widget.config?['id'] != null) 'id': widget.config!['id'],
    for (final entry in fields.entries)
      entry.key: entry.key == 'secretAccessKey'
          ? entry.value.text
          : entry.value.text.trim(),
    'pathStyle': pathStyle,
    'isDefault': isDefault,
    'enabled': enabled,
  };

  Future<void> _run(String action) async {
    if (busy || (action != 'delete' && !form.currentState!.validate())) return;
    if (action == 'delete') {
      final ok = await confirm(
        context,
        tr(context, '删除存储'),
        tr(context, '删除此存储配置？已有媒体由服务器保留引用。'),
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      busy = true;
      status = '';
    });
    try {
      final api = widget.session.api;
      if (action == 'test') {
        final config = input;
        if ((config['secretAccessKey'] as String).isEmpty) {
          config['secretAccessKey'] = widget.config?['secretAccessKey'] ?? '';
        }
        final message = await api.testStorage(config);
        if (mounted) setState(() => status = message);
      } else {
        if (action == 'delete') {
          await api.deleteStorage(widget.config!['id'] as String);
        } else {
          await api.saveStorage(input);
        }
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(widget.config == null ? '添加存储' : '编辑存储')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in fields.entries)
            TextFormField(
              controller: entry.value,
              enabled: !busy,
              obscureText: entry.key == 'secretAccessKey',
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: tr(
                  context,
                  {
                    'name': '名称',
                    'endpoint': 'HTTPS Endpoint',
                    'region': 'Region',
                    'bucket': 'Bucket',
                    'accessKeyId': 'Access Key ID',
                    'secretAccessKey': widget.config == null
                        ? 'Secret Access Key'
                        : 'Secret Access Key（留空保留）',
                  }[entry.key]!,
                ),
              ),
              validator: (value) {
                if (['endpoint', 'bucket', 'accessKeyId'].contains(entry.key) &&
                    (value?.trim().isEmpty ?? true)) {
                  return tr(context, '必填');
                }
                if (entry.key == 'secretAccessKey' &&
                    widget.config == null &&
                    (value?.isEmpty ?? true)) {
                  return tr(context, '必填');
                }
                if (entry.key == 'endpoint' &&
                    Uri.tryParse(value ?? '')?.scheme != 'https') {
                  return tr(context, '请输入 HTTPS 地址');
                }
                return null;
              },
            ),
          SwitchListTile(
            title: const AppText('路径式寻址'),
            value: pathStyle,
            onChanged: busy ? null : (v) => setState(() => pathStyle = v),
          ),
          SwitchListTile(
            title: const AppText('启用'),
            value: enabled,
            onChanged: busy ? null : (v) => setState(() => enabled = v),
          ),
          SwitchListTile(
            title: const AppText('默认上传存储'),
            value: isDefault,
            onChanged: busy ? null : (v) => setState(() => isDefault = v),
          ),
          FilledButton(
            onPressed: busy ? null : () => _run('save'),
            child: const AppText('保存'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => _run('test'),
            child: const AppText('测试连接'),
          ),
          if (widget.config != null)
            TextButton(
              onPressed: busy ? null : () => _run('delete'),
              child: const AppText('删除存储'),
            ),
          if (status.isNotEmpty) Text(status),
        ],
      ),
    ),
  );
}
