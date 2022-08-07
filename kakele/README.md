# kakele - Dissector for [Kakele Online](https://kakele.io/) messages

## Usage
1. Copy/symlink [kakele.lua](kakele/kakele.lua) and [kakele_prefs.lua](kakele/kakele_prefs.lua) to the [Wireshark plugin directory](https://www.wireshark.org/docs/wsug_html_chunked/ChPluginFolders.html)
2. Make sure contents of [proto/](kakele/proto) are within [protocol buffer search paths](https://www.wireshark.org/docs/wsug_html_chunked/ChProtobufSearchPaths.html)
3. Set the message types to be decoded in [protocol preferences](https://www.wireshark.org/docs/wsug_html_chunked/ChCustPreferencesSection.html)
