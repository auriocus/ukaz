set basedir [file dirname [info script]]
lappend auto_path [file join  $basedir ..]

package require ukaz
pack [ukaz::graph .g] -expand yes -fill both
set data {1 4.5 2 7.3 3 1.2 4 6.5}
.g plot $data with points pointtype filled-squares color "#A0FFA0"
.g set log y

.g plot {1 2 2.5 3.5 4 3} with lp yaxis y2


