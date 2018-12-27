#!/bin/bash
source path.sh
source cmd.sh


ls data/binaries/*.png | sort -r > data/tmp.flist
split -l 2000 -d data/tmp.flist data/tmp.flist.split
mv data/tmp.flist.split00 data/tmp.flist.split07

mkdir -p data/normalized
$train_cmd JOB=1:7 ./log/init.JOB.log /export/b01/babak/prepocressor-0.2.1/prepocressor -inputFile data/tmp.flist.split0JOB -outputPath "data/normalized/%base.png" -pipeline "grayscale| threshold -type BINARY,OTSU |vertTextSegmentation -minSlope 0.00000001 -minMargin 0.2 -concatChildren 1|transpose |vertTextSegmentation -minSlope 0.00000001 -minMargin 0.2 -concatChildren 1|transpose|houghTextLine|transpose|vertTextSegmentation -minSlope 0.00000001 -minMargin 0.2 -concatChildren 1|transpose|splitTextLines -minWidth 2.5|houghTextLine -resolution 200|concat|transpose|vertTextSegmentation -minSlope 0.00001 -minMargin 0.2 -concatChildren 1|transpose|houghTextLine |extend|textSkewCorrection -maxDegree 50|normalizeText -belowBaseline 20 -aboveBaseline 30|thinning|morph -operation dilate -kernelShape ellipse -kernelSize 3|normalize|blur -mode gauss -xSize 5 -ySize 5|normalize" -nThreads 8 -logLevel DEBUG
rm tmp.flist*
