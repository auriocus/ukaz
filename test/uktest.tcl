set basedir [file dirname [info script]]
set datafile [file join $basedir sine.dat]

lappend auto_path [file join  $basedir .. lib]
package require Tk
package require ukaz
ukaz::graph .g
ttk::label .l -textvariable status

grid .g -sticky nsew 
grid .l -sticky nsew
grid columnconfigure . 0 -weight 1
grid rowconfigure . 0 -weight 1

bind .g <<MotionEvent>> { set status "[join %d ,]" }
bind .g <<Click>> { puts "Clicked on %x,%y at [join %d ,]" }

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
