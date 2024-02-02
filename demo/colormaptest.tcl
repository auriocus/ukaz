set basedir [file dirname [info script]]
lappend auto_path [file join  $basedir ..]

package require ukaz
pack [ukaz::graph .g] -expand yes -fill both

#ukaz::testcolormap rgb
#ukaz::testcolormap jet
#ukaz::testcolormap hot
#ukaz::testcolormap gray	

set data {1 4.5 2 7.3 3 1.2 4 6.5}
set zdata { 1 2 3 4 }
.g plot $data with linespoints pointtype filled-squares color "#A1FFA0" varying color zdata $zdata colormap jet
.g set log y

.g plot {1 2 3 0.9} with points pt squares color blue


