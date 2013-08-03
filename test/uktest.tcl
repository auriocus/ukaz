set basedir [file dirname [info script]]
set datafile [file join $basedir sine.dat]

lappend auto_path [file join  $basedir .. lib]
package require Tk
package require ukaz
pack [ukaz::graph .g ] -expand yes -fill both -padx 5 -pady 5
.g plot $datafile using 1:2 with points pt filled-triangles color blue ps 1.0
.g plot $datafile using {1:(2*$2)} with lines color red lw 3
for {set i 0} {$i<1000} {incr i} {
	set x [expr {double($i)/100.0}]
	lappend data $x [expr {sin($x*2*3.1415926535/3.2)*exp(-$x/5.0)}]
}
.g plot $data w p pt filled-squares

ukaz::dragline d -variable v -orient horizontal
.g addcontrol d
set v 0
