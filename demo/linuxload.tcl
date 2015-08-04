# display load avg on Linux

package require ukaz
package require fileutil

pack [ukaz::graph .l] -expand yes -fill both

set lastload {0 0}
set time 0

proc newload {} {
	variable lastload
	variable time
	variable graphid
	
	# read current loadavg last 1, 5 and 15 minutes
	lassign [fileutil::cat /proc/loadavg] l1 l5 l15
	
	incr time
	lappend lastload $time $l1
	
	if {[llength $lastload]>1000} {
		# for more than 1000 entries, cut it down
		set lastload [lrange $lastload end-999 end]
	}
	.l update $graphid data $lastload
	after 500 newload
}

set graphid [.l plot $lastload with lines color red title "CPU load"]
.l set xlabel "Time"
.l set ylabel "Load"

newload
