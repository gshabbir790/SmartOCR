import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kAiBackendUrlPrefKey = 'ai_backend_url';
const kAutoOcrPrefKey = 'auto_ocr';
const kCloudFallbackPrefKey = 'cloud_ocr_fallback';
const kSaveOriginalsPrefKey = 'save_originals';

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key, required this.onThemeChanged}); final ValueChanged<ThemeMode> onThemeChanged; @override State<SettingsScreen> createState()=>_SettingsScreenState(); }
class _SettingsScreenState extends State<SettingsScreen>{
  bool auto=true;bool cloud=false;bool originals=true;
  final _urlController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      auto = prefs.getBool(kAutoOcrPrefKey) ?? true;
      cloud = prefs.getBool(kCloudFallbackPrefKey) ?? false;
      originals = prefs.getBool(kSaveOriginalsPrefKey) ?? true;
      _urlController.text = prefs.getString(kAiBackendUrlPrefKey) ?? '';
      _loaded = true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(kAiBackendUrlPrefKey);
    } else {
      await prefs.setString(kAiBackendUrlPrefKey, trimmed);
    }
  }

  @override
  void dispose() { _urlController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Settings')),body: !_loaded ? const Center(child: CircularProgressIndicator()) : ListView(padding:const EdgeInsets.all(16),children:[
    const ListTile(title:Text('Preferences',style:TextStyle(fontWeight:FontWeight.w800))),
    SwitchListTile(title:const Text('Auto OCR'),subtitle:const Text('Start OCR after import/share'),value:auto,onChanged:(v){setState(()=>auto=v);_saveBool(kAutoOcrPrefKey, v);}),
    SwitchListTile(title:const Text('Cloud OCR fallback'),subtitle:const Text('Only used when enabled'),value:cloud,onChanged:(v){setState(()=>cloud=v);_saveBool(kCloudFallbackPrefKey, v);}),
    SwitchListTile(title:const Text('Save original images'),value:originals,onChanged:(v){setState(()=>originals=v);_saveBool(kSaveOriginalsPrefKey, v);}),
    const Divider(),
    const ListTile(title:Text('AI backend',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Your own HTTPS endpoint (e.g. the bundled Cloudflare Worker). Leave blank to keep "Ask AI" offline.')),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _urlController, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://smart-ocr-api.example.workers.dev'), onSubmitted: _saveUrl, onEditingComplete: () => _saveUrl(_urlController.text))),
    const SizedBox(height: 12),
    const Divider(),
    ListTile(title:const Text('Theme'),trailing:DropdownButton<ThemeMode>(value:ThemeMode.system,items:const[DropdownMenuItem(value:ThemeMode.system,child:Text('System')),DropdownMenuItem(value:ThemeMode.light,child:Text('Light')),DropdownMenuItem(value:ThemeMode.dark,child:Text('Dark'))],onChanged:(v){if(v!=null)widget.onThemeChanged(v);})),
    const ListTile(title:Text('Privacy'),subtitle:Text('Basic OCR runs on device. Images are not silently uploaded.')),
    const ListTile(title:Text('About'),subtitle:Text('Smart OCR • Android-first OCR scanner')),
  ]));
}
