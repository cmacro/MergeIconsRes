# 合并Flag

```bat

MergeRes.exe -s flag\x1 -o flagx1 -p FlagX1

```

**生成内容**    

> 1. flagx1.bmp       ---- 带有alpha通道的bmp合并文件  
> 2. flagx1.inc       ---- 索引生成图标的资源顺序  
> 3. flagx1.IconPack  ---- 使用delphi自带库ZLib.TZCompressionStream 进行压缩的bmp文件  