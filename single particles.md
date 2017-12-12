# 单颗粒工作流程

[toc]


## 1. motion correction

>电子会使样品漂移，通过使用DDD收集极短曝光时间的一系列照片，减少漂移的影响。

- motioncor1

使用relionGUI调用，或命令行。bin按需，只能1或2  -fgr为gain reference路径

```bash
dosefgpu_drifcorr <inputfile> -bin 2 -fgr <gain reference>
```

- motioncor2

使用relionGUI调用，或命令行。RotGain：因为有些相机会转动，使用此命令将reference和照片的方向转到一样。

```bash
motioncor2 -InMrc <input mrc or folder> -Serial <0表示单张，1表示input文件夹> -Gain <gain reference> -RotGain <0,90,180,270>
```

## 2. ctf estimation
>我暂时还不不太讲得明白CTF

- relionGUI调用gctf或者ctffind4

I/O: micrograph STAR file: 输入文件的STAR列表。  
Microscopy: Spherical aberration:  Voltage: Amplitude contrast: Magnified pixel size  
Gctf: Use Gctf : Yes; Gctf executable: <Gctf路径>; Ignore CTFFIND parameter: Yes; Preform: No;  
Running: Number of MPI procs: 3?????

- 直接脚本调用gctf或ctffind4

## 3. evaluate micrographs & manual particle picking

>这一步是主要的手工工作步骤。手动选择颗粒，作为自动框的模板。

- 进行高斯gauss低通lowpass滤波

通过低通滤波来保留低频信息，更方便观察。

```bash
for i in `ls *,mrc | cut -d '.' -f '1'`; do e2proc2d.py $i.mrc $i.hdf --process filter.lowpass.gauss:cutoff_freq=0.05; done
```

cutoff\_freq的意思：apix/cufoff_freq=滤到的分辨率A值  
在这里1.254/0.05=25.08A  
并行的高斯滤波方法：  
滤波过程是一个CPU密集的工作，可以通过并行加速，不要超过8核，不然硬盘IO不足

```bash
for i in `ls *,mrc | cut -d '.' -f '1'`;do echo e2proc2d.py '$i.mrc' '$i.hdf' --process filter.lowpass.gauss:cutoff_freq=0.05;done > commandlist
runpar -proc <Number of processors to use> -file=commandlist
```

- 向eman中导入图片


不要用import这个功能，直接将滤波后的文件命名为micrographs或者创建一个同名软链接，避免把文件拷来拷去占用硬盘空间。
创建的文件夹的名字一定要是micrographs

```bash
ln -s <源目录> <e2projectmanager启动的目录/micrographs>
```

- 评估照片质量

e2boxer_old.py：  
在手动选颗粒时，顺便指定image quality。注意，默认照片质量为2。如果不选中照片，则不指定默认值。  
e2evalimage.py：  
在已经向eman中导入图片后，再次使用import菜单下的evaluate and import
可以看到defocus和B factor，由此指定每一张照片的质量。注意，默认照片质量为5。

- 根据照片质量生成列表

```bash
#生成一个包含照片名称和质量的列表
for i in `ls *_DW_info.json`; do echo $i `cat $i | grep '"quality":'`; done > qualitylist
#使用python脚本加上后缀和更改格式
python <script_name> qualitylist <想要的quality数值> > quality5
```

```python
#!/usr/bin/env python
from sys import argv
script, a ,quality= argv

for i in open(a,'r'):
    if i:
        if eval(i[44]) > eval(quality) :
            print 'micrographs/'+i[:22]+'.mrc',

```

- 手动选择颗粒

使用EMAN2.2的e2boxer.py进行  
点击选择颗粒

- 统计手动框选了多少个颗粒

```bash
cat <project文件夹>/info/*.json | grep 'manual' | wc -l
```

- 导出颗粒

EMAN2.2 generate output  
GUI：选择micrographs，填好boxsize，选择write_dbbox，如果有需要选择allmicrographs，指定apix。  
命令行：

```bash
e2boxer.py <inputfile> --boxsize=256 --ptclsize=160 --write_dbbox --apix=1.254
```

如果inputfile太多或者需要筛选，可以输入文件路径写成文本文件filelist，filelist之间的文件名用空格分开。  

```python
#!/usr/bin/env pyhton
#usage:
# python script_name inputfile
from sys import argv
script, inputfile = argv
for i in open(inputfile):
    if i:
        print i[:-1],
```

执行：

```bash
e2boxer.py echo `cat filelist` --boxsize=256 --write_dbbox --no_ctf --apix=1.254
```

- 去除超出边界的颗粒

判断方法:  
EMAN记录的是box的左下角坐标，图片的坐标原点在左下角  
0 < x值 < 照片x-boxsize  
0 < y值 < 照片y-boxsize

relion记录的是box中心坐标，图片的坐标原点在左上角  
0.5\*boxsize < x值 < 照片x-0.5\*boxsize  
0.5\*boxsize < y值 < 照片y-0.5\*boxsize

照片大小：  
K2: 3838×3710(counting) 7676×7420(super resolution)  
Falcon II: 4096×4096

```python
#!/usr/bin/env python
#usage:
#for i in `ls *.box`; do python remove_out_range.py $i ;done
#out put to folder 'inrange_box'

from sys import argv
import os

script,boxfile = argv
if os.path.exists('./inrange_box'):
    'do nothing'
else:
    os.makedirs('./inrange_box')
#新建一个文件夹容纳输出的boxfile

outfile = open ('./inrange_box'+'/'+boxfile.split('/')[-1],'w')

ori_box = 0
out_box = 0

for i in open(boxfile):
    ori_box+=1
    xy = i.split('\t')
    if int(xy[0])<3838-256 and int(xy[0])>0 and int(xy[1]) > 0 and int(xy[1]) < 3710-256:
        outfile.write("%s\t%s\t256\t256\n" % (xy[0],xy[1]))
        out_box+=1

print "%r/%r boxs selected from %s out put to ./inrange_box" % (out_box,ori_box,boxfile)
```

## 4. generate autopick reference
>autopick reference应该具有颗粒的信息，但是不能被个别的颗粒的信息影响，所以要通过Class average保留普遍的信息

### 使用Relion2.1

- Particle extraction:
<span id = 'extraction'></span>

I/O: micrograph STAR file: 输入文件的STAR列表。
Input coordinates: Filename of the coords_suffix file with the directory structure and the suffix of all coordinate files.; No; 空; Yes; No  
extract: Particle box size=在手动框选时的boxsize，Invert contrast按需要，将颗粒变为黑色, Normailze: Yes, 如果想要压缩，选择rescale: Yes， rescaled填写想要压缩到的boxsize  
Helix: No  
Running: Number of MPI: 1;
Submit to queue: No;

- 2D classification：
<span id = '2D'></span>

I/O:
选择上一步产生的STAR文件。  
CTF:
Yes No No.
optimisation:
Number of classes: ;
Number of iteration: ;
Regularisation parameter T:2 ;
Mask diameter: ;
Mask individual particles with zero: Yes;
limit resolution E-step(A): ;
Sampling:
Perform image alignment: yes;
In-plane angular sampling: 6;
offset search range : 5;
offset search step: 1;
Helix:
No
compute:
Yes; 3;pre-read all particles into RAM: Yes(颗粒少，内存可以装下时)No(内存不够大时);
; No; Use GPU acceleration: Yes(使用GPU)No(不用GPU);
Running:  
em3使用GPU:
Number of MPI: 3 Number of threads: 10 . Submit to queue? No

- Subset selection:

Select classes from model.star: 输入2d分类最后一轮的model文件;  
点击run，妥善设置行数，大小。从2D class里面选择subset，点击表示选中，右键save selected classes。

在这一步，应该注意选择具有明显特性的，边界明显，具有不同取向的颗粒。选出的颗粒位于Class2D/job???/classe_averages.mrcs

### EMAN2.2
同generate output，write\_dbbox改为write_ptcls
invert: 将颗粒变为白色

- particle sets - build particle sets
<span id = 'buildsets'></span>

stack file: 选择刚才输出的particles，也可以通过选中allparticles来选择所有在particles文件夹里面的

- 2D analysis - reference free class averaging
<span id = '2Danalysis'></span>>

input: sets/刚刚构建的particles set
ncls: 分类的数量 iter: 循环数 parallel: thread:20

- select class average
2D分类的结果位于 工程文件夹/r2d\_??/allrefs_05.hdf  
使用e2display.py 打开allrefs\_05,鼠标中键打开控制面板，点击Del，删除不好的class\_average。然后点击控制面板save保存。

### 对reference进行适当的滤波
将得到的reference滤波到15A，防止叠加产生的高频信号对autopick产生不好影响
方法参见4

## 5. autopick

### EMAN2.2

- 使用EMAN2.2的e2boxer.py

选择所有质量良好的照片，点击launch
点击2D ref打开reference文件，注意反差与照片应一致。打来后，产生一个新的名为ref的窗口，显示reference颗粒

- 导出颗粒  
参见4.

- 去除超出边界的颗粒
参见4.

### Gautomatch

```bash
Gautomatch --apixM <Apix of micrograph> --diameter <Particle diameter> --T <Template> --apixT <Apix of Template> <Micrographs>
```
By default,the program will invert the 'white' templates to 'black' before picking.Use ‐‐dont_invertT to avoid inversion

|Additional option|Default|Description|
|--ang_step|5|Angular step size|
|--speed|2|0,1,2,3,4,the bigger the faster less accurate  
|--boxsize|apix*diameter| 
|--min_dist|300|Minimum distance between particles in Angstrom  
|--cc_cutoff|0.1|Cross‐correlation cutoff

## 6. 2D classification
>2d 分类主要是为了去除不好的颗粒。一般来说，一个分类中的颗粒数量不多，则这个分类不靠谱，应当丢弃这个分类中的颗粒。 重复多次，直到分类稳定。

### Relion2.1

- particle extract

参考4.[particle extraction](#extraction)

-2D classification

参见4.[2D classification](#2D)


几个重要参数改动(对于数十万个颗粒)  
Number of classes: 200;
Number of iteration: 25;
Mask diameter: 稍大于目标蛋白大小或者直接填和boxsize一样;
limit resolution E-step(A): 15A

- 查看每个classes有多少个颗粒

```bash
for ((i=1;i<classess数量加一;i++));do cat run_it025_data.star | cut -b 290-300 | grep “  $i  “ | wc -l;done > QuantityList
```
cat的文件为最后一次运行产生的star文件，注意$i左右的空格不能少，cut-b定位到_rlnClassNumber所在列

cat -n QuantityList 中-n意思为显示行号

筛选多于某个数量的分类，如多于7000个颗粒的分类

```bash
cat QuantityList | grep "7[0-9] [0-9] [0-9]"
```


- continu old run

感觉iter轮数不够（每个分类数量较为平均），就可以再进行几轮。Continue from here: run\_iter<最后一轮>_optimiser.star


- subset selection

在Select classes from model.star一栏打开2d class产生的model文件，点run  
选择适当的scale，按需点击sort，点击Display  
选中（红色框中）理想的分类，右键选择save particles from selected classes
在relion的outout窗口会显示共输出了多少个particles，输出的文件为Select/job???/particles.star，

### EMAN2.2处理relion star file
- 新建工作目录

新建一个文件夹，使用软链接导入照片。方法参见3.[向eman中导入照片](#import)

- 导入来自relion的颗粒  
particles - Import Tools - Import .box or .star file  
选择来自relion的star文件，点击导入

- particle sets - build particle sets

参见4.[build particle sets](#buildsets)

- 2D analysis - reference free class averaging

参见4.[reference free class average](#2Danalysis)

## 7.3D Refinement


