# PathOfBuildingCN17173-Dev
 
这是S16赛季开始维护的国服POB项目，从原有项目上延续而来。

目前自动更新的功能还未完成，所以麻烦手动下载新版Release，手动覆盖文件进行更新。

如有Bug，请在Issue页面留下消息，也鼓励大家自己在代码中做出修改，提出PR。

# 脚本操作

生成manifest.xml:

    python update_manifest.py --in-place --set-version=${{ next-version }}