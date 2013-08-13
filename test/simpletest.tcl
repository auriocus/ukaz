set basedir [file dirname [info script]]
lappend auto_path [file join  $basedir .. lib]

if {0} {
package require ukaz
pack [ukaz::graph .g -width 500 -height 400] -expand yes -fill both
set data {1 4.5 2 7.3 3 1.2 4 6.5}
.g plot $data 
}

package require ukaz
pack [ukaz::graph .g] -expand yes -fill both
set data {1 4.5 2 7.3 3 1.2 4 6.5}
.g plot $data with points pointtype filled-squares color "#A0FFA0"
.g set log y


