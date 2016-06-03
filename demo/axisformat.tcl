set basedir [file dirname [info script]]
lappend auto_path [file dirname $basedir]

package require ukaz 2.0a3
pack [ukaz::graph .g  -width 500 -height 400] -expand yes -fill both
set t1 [clock scan "00:04:05"]
set t2 [clock scan "00:08:05"]
set data [list $t1 4.5 $t2 8]
.g plot $data 

proc percent {x} {
	format %.0f%% [expr {100*$x}]
}

.g set format x %H:%M:%S timedate
.g set format y percent command

# place a tic at every minute
.g set xtics 60 

