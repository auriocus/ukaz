package require snit
package require Tk 8.6
package provide ukaz 2.1

namespace eval ukaz {

	variable ns [namespace current]
	##### General functions ###############
	proc lremove {list element} {
		lsearch -all -inline -not -exact $list $element
	}

	##### Functions for geometric operations (clipping) ############
	namespace eval geometry {

		proc polylineclip {cdata range} {

			variable xmin [dict get $range xmin]
			variable xmax [dict get $range xmax]
			variable ymin [dict get $range ymin]
			variable ymax [dict get $range ymax]

			if {$xmin > $xmax} { lassign [list $xmin $xmax] xmax xmin }
			if {$ymin > $ymax} { lassign [list $ymin $ymax] ymax ymin }

			set result {}
			set piece {}

			# clip infinity of first point
			set x1 Inf
			set y1 Inf
			while {[indefinite $x1 $y1]} {
				set cdata [lassign $cdata x1 y1]
				if {[llength $cdata]<2} {
					return {}
				}
			}

			foreach {x2 y2} $cdata {
				# clip total indefinite points
				if {[indefinite $x2 $y2]} {
					# end last line
					if {$piece != {}} {
						lappend result $piece
					}
					set piece {}
					continue
				}

				lassign [cohensutherland $x1 $y1 $x2 $y2] clipline type
				switch $type {
					rightclip {
						# second point was clipped
						if {$piece == {}} {
							# it is the first line segment
							# make single segment
							lappend result $clipline
						} else {
							lappend piece {*}[lrange $clipline 2 3]
							lappend result $piece
							set piece {}
						}
					}

					leftclip {
						# first point was clipped, begin new line
						set piece $clipline
					}

					noclip {
						# append as given
						# if we are the first, include 1st point
						if {[llength $piece]==0} {
							set piece [list $x1 $y1]
						}
						lappend piece $x2 $y2
					}

					empty {
						# end last line
						if {$piece != {}} {
							lappend result $piece
						}
						set piece {}
					}

					bothclip {
						# create line on it's own

						# end last line
						if {$piece != {}} {
							lappend result $piece
						}
						set piece {}

						lappend result $clipline
					}

				}
				# advance
				set x1 $x2
				set y1 $y2
			}
			# end last line
			if {$piece != {}} {
				lappend result $piece
			}

			return $result
		}

		proc cohensutherland {x1 y1 x2 y2} {
			variable xmin
			variable xmax
			variable ymin
			variable ymax

			set codeleft [pointcode $x1 $y1]
			set coderight [pointcode $x2 $y2]
			if {($codeleft | $coderight) == 0} {
				return [list [list $x1 $y1 $x2 $y2] noclip]
			}

			if {($codeleft & $coderight) != 0} {
				return {{} empty}
			}

			# if we are here, one of the points must be clipped
			set left false
			set right false
			for {set iter 0} {$iter<20} {incr iter} {
				if {$codeleft != 0} {
					# left point is outside
					set left true
					lassign [intersect $x1 $y1 $x2 $y2] x1 y1
					set codeleft [pointcode $x1 $y1]
				} else {
					# right point outside
					set right true
					lassign [intersect $x2 $y2 $x1 $y1] x2 y2
					set coderight [pointcode $x2 $y2]
				}

				if {($codeleft & $coderight) != 0} {
					return {{} empty}
				}

				if {($codeleft | $coderight) == 0} {
					if {$left && $right} {
						return [list [list $x1 $y1 $x2 $y2] bothclip]
					}
					if {$left} {
						return [list [list $x1 $y1 $x2 $y2] leftclip]
					}
					if {$right} {
						return [list [list $x1 $y1 $x2 $y2] rightclip]
					}
					return "Can't happen $x1 $y1 $x2 $y2"
				}
			}
			return "Infinite loop $x1 $y1 $x2 $y2 "
		}


		proc pointcode {x y} {
			variable xmin
			variable xmax
			variable ymin
			variable ymax

			expr {(($x<$xmin)?1:0) |
					(($x>$xmax)?2:0) |
					(($y<$ymin)?4:0) |
					(($y>$ymax)?8:0) }
		}

		proc intersect {x1 y1 x2 y2} {
			variable xmin
			variable xmax
			variable ymin
			variable ymax

			# check for infinity
			if {$y1 == Inf} {
				return [list $x2 $ymax]
			}

			if {$y1 == -Inf} {
				return [list $x2 $ymin]
			}

			if {$x1 == Inf} {
				return [list $xmax $y2]
			}

			if {$x1 == -Inf} {
				return [list $xmin $y2]
			}

			if {$y1>$ymax} {
				return [list [expr {$x1+($x2-$x1)*($ymax-$y1)/($y2-$y1)}] $ymax]
			}

			if {$y1<$ymin} {
				return [list [expr {$x1+($x2-$x1)*($ymin-$y1)/($y2-$y1)}] $ymin]
			}

			if {$x1>$xmax} {
				return [list $xmax [expr {$y1+($y2-$y1)*($xmax-$x1)/($x2-$x1)}]]
			}

			return [list $xmin [expr {$y1+($y2-$y1)*($xmin-$x1)/($x2-$x1)}]]
		}

		proc indefinite {x y} {
			expr { ($x!=$x) || ($y != $y) || (abs($x) == Inf && abs($y) == Inf)}
		}

		proc pointclipz {cdata zdata range} {
			# remove all points which are NaN or outside
			# the clip region
			set xmin [dict get $range xmin]
			set xmax [dict get $range xmax]
			set ymin [dict get $range ymin]
			set ymax [dict get $range ymax]
			set zmin [dict get $range zmin]
			set zmax [dict get $range zmax]
			
			set result {}
			set resultz {}
			set clipinfo {}
			set clipid 0
			foreach {x y} $cdata z $zdata {
				if {$x!=$x || $y!=$y || $x<$xmin || $x>$xmax || $y<$ymin || $y>$ymax || $z!=$z || $z > $zmax || $z < $zmin} {
					dict incr clipinfo $clipid
					continue
				}
				lappend result $x $y
				lappend resultz $z
				incr clipid
			}
			list $result $resultz $clipinfo
		}
		
		proc pointclip {cdata range} {
			# remove all points which are NaN or outside
			# the clip region
			set xmin [dict get $range xmin]
			set xmax [dict get $range xmax]
			set ymin [dict get $range ymin]
			set ymax [dict get $range ymax]
			set result {}
			set clipinfo {}
			set clipid 0
			foreach {x y} $cdata {
				if {$x!=$x || $y!=$y || $x<$xmin || $x>$xmax || $y<$ymin || $y>$ymax} {
					dict incr clipinfo $clipid
					continue
				}
				lappend result $x $y
				incr clipid
			}
			list $result $clipinfo
		}
	}

	############## Functions for colormaps          ############################
	
	variable colormaps {}
	proc mkcolormap {name map} {
		# Create a colormap from a list of colors in float format with attached 
		# gradient stops from 0 to 1.
		#
		# example: mkcolormap redgreen {0 {1.0 0.0 0.0} 1 {0.0 1.0 0.0} }
		# The colormap is a long list of interpolated colors in hex format (#xxyyzz)
		
		variable colormaps
		
		if {[dict exists $colormaps $name]} {
		   return -code error "Colormap $name already exists"
		}

		set maxcols 2000 ;# should be 2000 for real maps
		set cmap {}
		set map [lassign $map stop fcolor]
		
		if {$stop != 0} {
			return -code error "First color must be at index 0.0"
		}
		
		for {set i 0} {$i < $maxcols} {incr i} {
			set frac [expr {double($i) / ($maxcols - 1)}]
			if {($frac > $stop) || ($i == 0)} {
				# advance
				set oldstop $stop
				set oldfcolor $fcolor
				set map [lassign $map stop fcolor]
			}

			lappend cmap [interpol_color $oldstop $oldfcolor $stop $fcolor $frac]
		}
		
		if {$stop != 1.0 } {
			return -code error "Final color stop must be 1.0"
		}

		dict set colormaps $name $cmap
	}

	proc getcolor {map stop} {
		set maplength [llength $map]
		set index [expr {min(max(int($maplength*$stop), 0),$maplength - 1)}]
		return [lindex $map $index]
	}

	proc getcolormap {name} {
		variable colormaps
		dict get $colormaps $name
	}

	proc interpol_color {x0 color0 x1 color1 frac} {
		set w1 [expr {double($frac - $x0)/($x1 - $x0)}]
		set w0 [expr {1.0 - $w1}]

		foreach c0 $color0 c1 $color1 {
			lappend fcolor [expr {$c0*$w0 + $c1*$w1}]
		}

		set icolor [lmap f $fcolor {expr {min(max(int($f*255), 0),255)}}]

		set xcolor [join [lmap i $icolor {format %02x $i}] ""]
		return "#$xcolor"
	}
		
	proc testcolormap {name} {
		variable colormaps
		toplevel .ctest
		wm title .ctest "Colormap $name"
		set cmap [dict get $colormaps $name]

		set width 400
		set height 50
		pack [canvas .ctest.c -width $width -height $height] -expand yes -fill both
		for {set x 0} {$x < $width} {incr x} {
			set frac [expr {double($x) / ($width - 1)}]
			.ctest.c create rectangle $x 0 $x $height -outline {} -fill [getcolor $cmap $frac]
		}
		tkwait window .ctest
	}
	
	# add a few standard colormaps
	
	mkcolormap rgb {0 {1.0 0.0 0.0} 0.5 {0.0 1.0 0.0} 1.0 {0.0 0.0 1.0}}
	
	mkcolormap jet { 
		0     { 0 0 0.5 }
		0.125 { 0 0 1 }
		0.325 { 0 1 1 }
		0.625 { 1 1 0 }
		0.875 { 1 0 0 }
		1     { 0.5 0 0 }
	}
	
	mkcolormap gray {0 {0 0 0}  1 {1 1 1}}

	mkcolormap hot {
		0 {0 0 0}
		0.25 {1 0 0}
		0.7 { 1 1 0}
		1   { 1 1 1 }
	}
	
	proc cutoff_log {x} {
		# expr throws error if log is NaN
		if {$x <= 0} { return -Inf }
		return [expr {log($x)}]
	}

	############## Functions for deferred execution ############################
	variable Requests {}
	proc defer {cmd} {
		# defer cmd to idle time. Multiple requests are merged
		variable ns
		variable Requests
		if {[dict size $Requests] == 0} {
			after idle ${ns}::doRequests
		}

		dict set Requests $cmd 1
	}

	proc doRequests {} {
		variable Requests

		# first clear Requests, so that new requests are only recorded
		# during execution and do not interfere with the execution
		set ReqCopy $Requests
		set Requests {}
		dict for {cmd val} $ReqCopy {
			uplevel #0 $cmd
		}
	}

	########## Functions for math on data ##############################
	proc parsedata_using {fdata args} {
		# read column data
		# analogous to "using" in gnuplot
		# the elements of formatlist are interpreted as expr-String with embedded $0, $1, ...
		# return as flat a list
		set ncomments 0
		set nblanks 0
		set ndata 0
		set skip 0

		variable parseerrors {}
		set 0 0
		set lno 0
		set result {}
		# $0 contains the linenumber, initially it's 0
		foreach line [split $fdata \n] {
			# make list
			incr lno
			set cols [regexp -all -inline {[^[:space:]]+} $line]
			# puts "$0: $cols"
			if {[regexp {^[[:space:]]*#} $line]} {
				# it is a comment starting with "#"
				#puts "Comment $line"
				incr ncomments
				continue
			}

			if {[llength $cols]==0} {
				# blank line
				#puts "Blank line"
				incr nblanks
				continue
			}
			# puts $line
			# extract the columns and put them as double into $ind
			# if possible
			namespace eval formula [list set 0 $0]
			namespace eval formula [list set lno $lno]
			for {set ind 1} {$ind<=[llength $line]} {incr ind} {
				set indtext [lindex $line [expr {$ind - 1}]]
				if {[string is double -strict $indtext]} {
					namespace eval formula [list set $ind $indtext]
				}
			}

			set thisline {}
			set err {}
			foreach fmt $args {
				if {[catch {namespace eval formula [list expr $fmt]} datum]} {
					set err $datum
					break
				}
				lappend thisline $datum
			}

			namespace delete formula

			if {$err != {}} {
				lappend parseerrors "Line $lno: $err"
				incr skip
			} else {
				lappend result $thisline
				incr 0
				incr ndata
			}

		}

		variable parseinfo [list $ndata $ncomments $nblanks $skip]
		# return as a list of lists
		return $result
	}


	proc transformdata_using {data using} {
		# read file the same way as gnuplot does
		lassign [split $using :] xformat yformat
		if {[string is integer -strict $xformat] && $xformat >=0} {
			set xformat "\$$xformat"
		}
		if {[string is integer -strict $yformat] && $yformat >=0} {
			set yformat "\$$yformat"
		}
		set fd [open $data r]
		set fdata [read $fd]
		close $fd
		concat {*}[parsedata_using $fdata $xformat $yformat]
	}

	############## Functions for intervals ##################
	proc calcdatarange {data zdata}  {
		# compute min/max and corresponding log min/max
		# for dataset
		# unfortunately, four cases for log on/off must be considered
		# indexes into list are logx & logy
		set xmin {{+Inf +Inf} {+Inf +Inf}}
		set xmax {{-Inf -Inf} {-Inf -Inf}}
		set ymin {{+Inf +Inf} {+Inf +Inf}}
		set ymax {{-Inf -Inf} {-Inf -Inf}}
		foreach {x y} $data {
			set xfin [list [expr {isfinite($x)}]  [expr {islogfinite($x)}]]
			set yfin [list [expr {isfinite($y)}]  [expr {islogfinite($y)}]]

			foreach logx {0 1} {
				foreach logy {0 1} {
					if {[lindex $xfin $logx] && [lindex $yfin $logy]} {
						if {$x<[lindex $xmin $logx $logy]} { lset xmin $logx $logy $x}
						if {$x>[lindex $xmax $logx $logy]} { lset xmax $logx $logy $x}
						if {$y<[lindex $ymin $logx $logy]} { lset ymin $logx $logy $y}
						if {$y>[lindex $ymax $logx $logy]} { lset ymax $logx $logy $y}
					}
				}
			}
		}

		# For z values, i.e. color code, finiteness is independent
		# from x & y log values
		set zmin {+Inf +Inf}
		set zmax {-Inf -Inf}
		
		foreach z $zdata {
			set zfin [list [expr {isfinite($z)}]  [expr {islogfinite($z)}]]
			foreach logz {0 1} {
				if {[lindex $zfin $logz]} {
					if {$z<[lindex $zmin $logz]} { lset zmin $logz $z}
					if {$z>[lindex $zmax $logz]} { lset zmax $logz $z}
				}
			}
		}
		
		dict create xmin $xmin ymin $ymin xmax $xmax ymax $ymax zmin $zmin zmax $zmax
	}

	proc combine_range {range1 range2} {
		if {$range1 == {}} { return $range2 }
		if {$range2 == {}} { return $range1 }
		set result {}
		foreach key {xmin ymin} {
			set l1 [dict get $range1 $key]
			set l2 [dict get $range2 $key]
			foreach logx {0 1} lx1 $l1 lx2 $l2 {
				foreach logy {0 1} v1 $lx1 v2 $lx2 {
					lset l1 $logx $logy [expr {min($v1, $v2)}]
				}
			}
			dict set result $key $l1
		}
		foreach key {xmax ymax} {
			set l1 [dict get $range1 $key]
			set l2 [dict get $range2 $key]
			foreach logx {0 1} lx1 $l1 lx2 $l2 {
				foreach logy {0 1} v1 $lx1 v2 $lx2 {
					lset l1 $logx $logy [expr {max($v1, $v2)}]
				}
			}
			dict set result $key $l1
		}

		set l1 [dict get $range1 zmin]
		set l2 [dict get $range2 zmin]
		foreach logz {0 1} v1 $l1 v2 $l2 {
			lset l1 $logz [expr {min($v1, $v2)}]
		}
		dict set result zmin $l1

		set l1 [dict get $range1 zmax]
		set l2 [dict get $range2 zmax]
		foreach logz {0 1} v1 $l1 v2 $l2 {
			lset l1 $logz [expr {max($v1, $v2)}]
		}
		dict set result zmax $l1
			
		return $result
	}

	proc sanitize_range {rmin rmax} {
		# make a range with a finite span
		if {$rmin > $rmax} {
			# range contains not a single valid point
			# just return a default
			lassign {0.0 1.0} rmin rmax
		}

		if {$rmin == $rmax} {
			# range contains only one single point
			# expand range by a small width
			set rm $rmin
			if {$rm != 0} {
				# if it is a finite number, make a range 
				# with a relative size of +/- 0.1 %
				set rmin [expr {$rm*0.999}]
				set rmax [expr {$rm*1.001}]
				if {$rm < 0} {
					lassign [list $rmin $rmax] rmax rmin
				}
			} else {
				# if the only valid number is 0 
				# make a fixed range
				lassign {-0.001 0.001} rmin rmax
			}
		}

		return [list $rmin $rmax]
	}

	proc compute_rangetransform {r1min r1max r2min r2max} {
		set mul [expr {($r2max - $r2min)/($r1max -$r1min)}]
		set add [expr {$r2min-$r1min*$mul}]
		list $mul $add
	}

	############ Function for automatic axis scaling ##########
	proc compute_ticlist {min max tics log widen formatcmd} {
		# automatically compute sensible values
		# for the tics position, if not requested otherwise
		lassign $tics ticrequest spec
		switch $ticrequest {
			off {
				return [list {} $min $max]
			}

			list {
				set ticlist {}
				foreach v $spec {
					if {[string is double -strict $v]} {
						lappend ticlist [{*}$formatcmd $v] $v
					} elseif {[llength $v]==2} {
						lassign $v text pos
						lappend ticlist $text $pos
					}
				}
				return [list $ticlist $min $max]
			}

			every {
				# put a tic mark at integer multiples of spec
				set ticbase $spec
			}

			auto {
				# automatic placement. In log case,
				# put a mark at every power of ten
				# and subdivide for small span
				if {$log} {
					set decades [expr {log10($max)-log10($min)}]

					if {$decades<=2} {
						set minor {1 2 3 4 5}
					} elseif {$decades<=3} {
						set minor {1 2 5}
					} elseif {$decades<=5} {
						set minor {1 5}
					} else {
						set minor {1}
					}

					set expmin [expr {entier(floor(log10($min)))}]
					set expmax [expr {entier(floor(log10($max)))}]

					# the range is between 10^expmin and 10^(expmax+1)

					# if widening downwards, look for the largest
					# tic that is smaller or equal to the required minimum
					if {[dict get $widen min]} {
						foreach mantisse $minor {
							set tic [expr {$mantisse*10.0**$expmin}]
							if {$tic <= $min} {
								set wmin $tic
							}
						}
						set min $wmin
					}

					set ticlist {}

					for {set exp $expmin} {$exp <= $expmax} {incr exp} {
						set base [expr {10.0**$exp}]
						foreach mantisse $minor {
							set tic [expr {$mantisse*$base}]
							if {$tic >= $min && $tic <=$max} {
								lappend ticlist [{*}$formatcmd $tic] $tic
							}
						}
					}

					# if widening upwards, look for a tic >= the requested max
					# unles it has been reached before
					if {[dict get $widen max] && [lindex $ticlist end]<$max} {
						lappend minor 10
						foreach mantisse $minor {
							set tic [expr {$mantisse*10.0**$expmax}]
							if {$tic >= $max} {
								set max $tic
								lappend ticlist [{*}$formatcmd $tic] $tic
								break
							}
						}
					}

					return [list $ticlist $min $max]
				} else {
					# automatic placement. In linear case,
					# compute value as a multiple
					# of 1, 2 or 5 times a power of ten
					set exp [expr {log10(abs($max - $min))}]
					set base [expr {pow(10, floor($exp)-1)}]

					set xfrac [expr {fmod($exp, 1.0)}]
					if {$xfrac < 0 } {set xfrac [expr {$xfrac+1.0}]}
					# Exponent und Bruchteil des Zehnerlogarithmus
					set xb 10
					if {$xfrac <= 0.70} { set xb 5}
					if {$xfrac <= 0.31} { set xb 2}

					set ticbase [expr {$xb*$base}]
				}
			}

			default {
				error "Unknown tic mode $ticrequest"
			}
		}

		# if we are here, place marks at regular intervals
		# at integer multiples of ticbase
		# if we should widen, update min & max
		if {[dict get $widen min] && !$log} {
			set start [expr {entier(floor(double($min)/double($ticbase)))}]
			set min [expr {$ticbase*$start}]
		} else {
			set start [expr {entier(ceil(double($min)/double($ticbase)))}]
		}

		if {[dict get $widen max]} {
			set stop [expr {entier(ceil(double($max)/double($ticbase)))}]
			set max [expr {$ticbase*$stop}]
		} else {
			set stop [expr {entier(floor(double($max)/double($ticbase)))}]
		}

		set ticlist {}
		for {set i $start} {$i<=$stop} {incr i} {
			set v [expr {$i*$ticbase}]
			# if {$log && $v<=0} { continue }
			lappend ticlist [{*}$formatcmd $v] $v
		}
		return [list $ticlist $min $max]
	}

	######### Functions for parsing gnuplot style commands ###########
	proc initparsearg {{defaultdict {}}} {
		# checks whether args is a valid dictionary
		upvar 1 args procargs
		if {[catch {dict size $procargs}]} {
			return -code error -level 2 "Malformed argument list: $procargs"
		}
		variable parsearg_default $defaultdict
		variable parsearg_result {}
	}

	proc parsearg {option default} {
		# read argument from args, set to default
		# if unset in args. option can have alternative
		# names. Return true if the option was set
		# from the arguments, false if the default was substituted
		upvar 1 args procargs
		set optname [lindex $option 0]
		upvar 1 $optname resvar
		set success false
		foreach name $option {
			if {[dict exists $procargs $name]} {
				set resvar [dict get $procargs $name]
				dict unset procargs $name
				set success true
			}
		}

		variable parsearg_default
		variable parsearg_result

		if {!$success} {
			# set to default. First check the default dict
			# then use the hardcoded default
			if {[dict exists $parsearg_default $optname]} {
				set resvar [dict get $parsearg_default $optname]
			} else {
				set resvar $default
			}
		}

		dict set parsearg_result $optname $resvar
		return $success
	}

	proc errorargs {} {
		# call at the end to err on unknown options
		upvar 1 args procargs
		if {[llength $procargs] != 0} {
			return -code error -level 2 "Unknown argument(s) $procargs"
		}
	}

	proc parsearg_asdict {} {
		variable parsearg_result
		return $parsearg_result
	}

	########### Functions for drawing marks on a canvas ##############
	proc shape-circles {can coord color size width dash varying tag} {
		set ids {}
		foreach {x y} $coord {*}$varying {
			set r [expr {5.0*$size}]
			lappend ids [$can create oval \
				[expr {$x-$r}] [expr {$y-$r}] \
				[expr {$x+$r}] [expr {$y+$r}] \
				-outline $color -fill "" -width $width -dash $dash -tag $tag]
		}
		return $ids
	}

	proc shape-filled-circles {can coord color size width dash varying tag} {
		set ids {}
		foreach {x y} $coord {*}$varying {
			set r [expr {5.0*$size}]
			lappend ids [$can create oval \
				[expr {$x-$r}] [expr {$y-$r}] \
				[expr {$x+$r}] [expr {$y+$r}] \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}

	proc shape-squares {can coord color size width dash varying tag} {
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {5.0*$size}]
			lappend ids [$can create rectangle  \
				[expr {$x-$s}] [expr {$y-$s}] [expr {$x+$s}] [expr {$y+$s}] \
				-outline $color -fill "" -width $width -dash $dash -tag $tag]
		}
		return $ids
	}

	proc shape-filled-squares {can coord color size width dash varying tag} {
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {5.0*$size}]
			lappend ids [$can create rectangle  \
				[expr {$x-$s}] [expr {$y-$s}] [expr {$x+$s}] [expr {$y+$s}] \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}


	proc shape-hexagons {can coord color size width dash varying tag} {
		set clist {1 -0.5 0 -1.12 -1 -0.5 -1 0.5 0 1.12 1 0.5}
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {5.0*$size}]
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline $color -fill "" -width $width -dash $dash -tag $tag]
		}
		return $ids
	}

	proc shape-filled-hexagons {can coord color size width dash varying tag} {
		set clist {1 -0.5 0 -1.12 -1 -0.5 -1 0.5 0 1.12 1 0.5}
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {5.0*$size}]
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}

	proc shape-triangles {can coord color size width dash varying tag} {
		set clist {0.0 +1.0 0.5 -0.5 -0.5 -0.5}
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {8.0*$size}]
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline $color -fill "" -width $width -dash $dash -tag $tag]
		}
		return $ids
	}

	proc shape-filled-triangles {can coord color size width dash varying tag} {
		set clist {0.0 +1.0 0.5 -0.5 -0.5 -0.5}
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {8.0*$size}]
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}

	proc shape-uptriangles {can coord color size width dash varying tag} {
		set clist {0.0 -1.0 0.5 0.5 -0.5 0.5}
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {8.0*$size}]
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline $color -fill "" -width $width -dash $dash -tag $tag]
		}
		return $ids
	}

	proc shape-filled-uptriangles {can coord color size width dash varying tag} {
		set clist {0.0 -1.0 0.5 0.5 -0.5 0.5}
		set ids {}
		foreach {x y} $coord {*}$varying {
			set s [expr {8.0*$size}]
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}

	snit::widgetadaptor graph {
		delegate option -width to hull
		delegate option -height to hull
		delegate option -background to hull

		option -xrange -default {* *} -configuremethod rangeset
		option -yrange -default {* *} -configuremethod rangeset
		option -zrange -default {* *} -configuremethod rangeset
		option -logx -default 0 -configuremethod opset
		option -logy -default 0 -configuremethod opset
		option -logz -default 0 -configuremethod opset
		option -grid -default false -configuremethod opset
		option -xtics -default auto -configuremethod opset
		option -ytics -default auto -configuremethod opset
		option -ztics -default auto -configuremethod opset
		option -xlabel -default {} -configuremethod opset
		option -ylabel -default {} -configuremethod opset
		option -xformat -default %g -configuremethod opset
		option -yformat -default %g -configuremethod opset
		option -zformat -default %g -configuremethod opset
		option -font -default {} -configuremethod fontset
		option -ticlength -default 5
		option -samplelength -default 20
		option -samplesize -default 1.0
		option -key -default {vertical top horizontal right disabled false outside inside}
		option -keyspacing -default 1.0

		option -enhanced -default false -configuremethod unimplemented
		option -redraw -default 0 -readonly yes

		option -displayrange -readonly yes -cgetmethod getdisplayrange
		option -displaysize -readonly yes -cgetmethod getdisplaysize

		# backing store for plot data
		variable plotdata {}
		variable labeldata {}
		variable datasetnr 0
		variable zstack {}

		# computed list of tics and displayrange
		variable xticlist
		variable yticlist
		variable zticlist
		variable displayrange
		variable displaysize

		# store the history of ranges
		# by zooming with the mouse
		variable zoomstack {}

		# state during mouse action (dragging or clicking)
		variable dragdata {dragging false clicking false}

		# identity transform
		variable transform {1.0 0.0 1.0 0.0 1.0 0.0}

		variable axisfont default
		variable labelfont default

		# store for the interactive elements (=controls)
		variable controls {}

		constructor {args} {
			installhull using canvas
			$self configurelist $args
			bind $win <Configure> [mymethod RedrawRequest]

			# bindings for dragging & clicking
			bind $win <ButtonPress-1> [mymethod drag start %x %y]
			bind $win <Button1-Motion> [mymethod drag move %x %y]
			bind $win <ButtonRelease-1> [mymethod drag end %x %y %s]
			bind $win <ButtonRelease-2> [mymethod zoomout]
			bind $win <ButtonRelease-3> [mymethod zoomout]
			bind $win <Motion> [mymethod motionevent %x %y]

		}

		destructor {
			foreach c $controls {
				# release all embedded controls
				catch {$c Parent {} {}}
			}
		}

		method unimplemented {op value} {
			return -code error "Option $op not implemented"
		}

		method opset {op value} {
			set options($op) $value
			$self RedrawRequest
		}

		method RedrawRequest {} {
			defer [mymethod Redraw]
			return {}
		}

		#################### gnuplot style interface functions###########
		method plot {data args} {
			# main plot command
			# simulate gnuplot
			# syntax plot <data>
			#	?using usingspec?
			#	?with lines/points/linespoints?
			#	?color colorspec?
			#	?pointtype ...?
			#	?pointsize ...?
			#	?linewidth ...?
			#	?dash ...?
			#	?title ...?
			initparsearg
			parsearg {using u} {}
			parsearg {with w} points
			parsearg {color lc} auto
			parsearg {pointtype pt} circles
			parsearg {pointsize ps} 1.0
			parsearg {linewidth lw} 1.0
			parsearg {dash} ""
			parsearg {title t} ""
			parsearg {varying} {}
			parsearg {colormap} "jet"
			parsearg {zdata} {}

			if {$using != {}} {
				set data [transformdata_using $data $using]
			}

			if {$color == "auto"} {
				set colors {red green blue black}
				set ncolors [llength $colors]
				set color [lindex $colors [expr {$datasetnr%$ncolors}]]
			}

			set datarange [calcdatarange $data $zdata]

			set plotwith {}

			set id $datasetnr
			switch $with {
				p -
				points {
					dict set plotwith points 1
				}
				l -
				lines {
					dict set plotwith lines 1
				}

				lp -
				linespoints {
					dict set plotwith points 1
					dict set plotwith lines 1
				}

				n -
				none {
					dict unset plotwith points
					dict unset plotwith lines
				}

				default {
					return -code error "with must be: points, lines, linespoints or none"
				}
			}


			if {[dict exists $plotwith points]} {
				# check that pointtype exists
				lassign [info commands shape-$pointtype] ptproc
				if {$ptproc ne "shape-$pointtype"} {
					return -code error "Unknown pointtype $pointtype"
				}
			}

			dict set plotdata $id type $plotwith
			dict set plotdata $id data $data
			dict set plotdata $id datarange $datarange
			dict set plotdata $id color $color
			dict set plotdata $id pointtype $pointtype
			dict set plotdata $id pointsize $pointsize
			dict set plotdata $id title $title
			#
			dict set plotdata $id linewidth $linewidth
			dict set plotdata $id dash $dash
			dict set plotdata $id varying $varying
			dict set plotdata $id colormap $colormap
			dict set plotdata $id zdata $zdata

			lappend zstack $id
			$self RedrawRequest
			incr datasetnr
			return $id
		}

		method update {id args} {
			# same as plot, but change existing dataset
			if {![dict exists $plotdata $id]} {
				return -code error "No such dataset: $id"
			}

			initparsearg

			# check if new data was received
			# either by setting data or zdata
			set newdata false
			set newzdata false
			if {[parsearg data NONE]} {
				# new data was supplied. Only then check for transformation
				if {[parsearg {using u} {}]} {
					set data [transformdata_using $data $using]
				}
				set newdata true
			}

			if {[parsearg zdata NONE]} {
				set newzdata true
			}

			if {$newdata || $newzdata} {
				if {!$newzdata} {
					set zdata [dict get $plotdata $id zdata]
				}
				
				if {!$newdata} {
					set data [dict get $plotdata $id data]
				}

				set datarange [calcdatarange $data $zdata]
				dict set plotdata $id data $data
				dict set plotdata $id zdata $zdata
				dict set plotdata $id datarange $datarange
			}

			if {[parsearg {with w} {}]} {
				switch $with {
					p -
					points {
						dict set plotdata $id type points 1
						dict unset plotdata $id type lines
					}

					l -
					lines {
						dict set plotdata $id type lines 1
						dict unset plotdata $id type points
					}

					lp -
					linespoints {
						dict set plotdata $id type points 1
						dict set plotdata $id type lines 1
					}

					n -
					none {
						dict unset plotdata $id type points
						dict unset plotdata $id type lines
					}

					default {
						return -code error "with must be: points, lines, linespoints or none"
					}
				}
			}

			parsearg {color lc} auto
			if {$color != "auto"} {
				dict set plotdata $id color $color
			}

			foreach {option property} {
				{varying} varying
				{colormap} colormap
				{pointtype pt} pointtype
				{pointsize ps} pointsize
				{linewidth lw} linewidth
				{dash} dash
				{title t} title
			} {
				if {[parsearg $option {}]} {
					dict set plotdata $id $property [set $property]
				}
			}

			$self RedrawRequest
		}


		method remove {id} {
			set oldzstacklen [llength $zstack]
			dict unset plotdata $id
			set zstack [lremove $zstack $id]
			if {$oldzstacklen != [llength $zstack]} {
				# redraw only if we actually deleted something
				$self RedrawRequest
			}
		}

		method raise {id} {
			 if {[dict exists $plotdata $id]} {
				 set zstack [lremove $zstack $id]
				 lappend zstack $id
				 $self RedrawRequest
			}
		}

		method lower {id} {
			 if {[dict exists $plotdata $id]} {
				 set zstack [linsert [lremove $zstack $id] 0 $id]
				 $self RedrawRequest
			}
		}

		method {set log} {{what xy} {how on}} {
			# cast boolean how into canonical form 0,1
			if {![string is boolean -strict $how]} {
				return -code error "Expected boolean value instead of $how"
			}

			if {$how} {
				set how 1
			} else {
				set how 0
			}

			switch $what {
				x { $self configure -logx $how }
				y { $self configure -logy $how }
				xy {
					$self configure -logx $how
					$self configure -logy $how
				}
				z  { $self configure -logz $how }
				default {
					return -code error "Unknown axis for log setting $what"
				}
			}
		}

		method {unset log} {{what {}}} {
			$self set log $what off
		}


		# helper function to parse gnuplot-style ranges
		proc rangeparse {arglist} {
			if {[llength $arglist]==1} {
				# single string in gnuplot form - decompose at :
				# after removal of [] (potentially)
				set rangestring [lindex $arglist 0] ;# unpack

				if {[string trim $rangestring]=="auto"} { return [list * *] }

				set arglist [split [string trim $rangestring {[]} ] :]
			}

			if {[llength $arglist]==2} {
				# argument is a Tcl list min max
				lassign $arglist min max

				set min [string trim $min]
				set max [string trim $max]

				if {$min == ""} { set min * }
				if {$max == ""} { set max * }

				if {(!isfinite($min) && $min!="*") || (!isfinite($max) && $max !="*")} {
					return -code error -level 2 "Range limits must be floats or *; got $min:$max"
				}
			} else {
				return -code error -level 2 "Range must consist of two limits min:max"
			}

			list $min $max
		}

		method {set xrange} {args} {
			set options(-xrange) [rangeparse $args]
			$self RedrawRequest
		}

		method {set yrange} {args} {
			set options(-yrange) [rangeparse $args]
			$self RedrawRequest
		}
		
		method {set zrange} {args} {
			set options(-zrange) [rangeparse $args]
			$self RedrawRequest
		}

		method {set auto x} {} {
			$self set xrange *:*
		}

		method {set auto y} {} {
			$self set yrange *:*
		}

		method {set auto z} {} {
			$self set zrange *:*
		}

		method {set grid} {{how on}} {
			if {$how} {
				set options(-grid) on
			} else {
				set options(-grid) off
			}
			$self RedrawRequest
		}

		method {unset grid} {} {
			$self set grid off
		}

		proc parsetics {arglist} {
			if {[llength $arglist]==1} {
				# unpack
				set val [lindex $arglist 0]
				set sval [string trim $val]
				# either auto or double value
				if {$sval=="auto" || $sval == "off"} {
					return $sval
				} else {
					if {[llength $val]==1} {
						# try to parse as float
						if {isfinite($val) && $val > 0} {
							return [list every $val]
						} else {
							return -code error -level 2 "Single value tics must be positive float or \"auto\" or \"off\""
						}
					}
				}
			}

			# check for float value at every odd pos
			foreach val $arglist {
				if {[llength $val]==1} {
					if {!isfinite($val)} {
						return -code error -level 2 "Tics position must be float: $val"
					}
				} elseif {[llength $val]==2} {
					lassign $val text pos
					if {!isfinite($pos)} {
						return -code error -level 2 "Tics position must be float: $val"
					}
				} else {
					return -code error -level 2 "Tics sublists must consist of label and position: \{$val\}"
				}
			}

			list list $arglist
		}

		method {set xtics} {args} {
			set options(-xtics) [parsetics $args]
			$self RedrawRequest
		}

		method {set ytics} {args} {
			set options(-ytics) [parsetics $args]
			$self RedrawRequest
		}

		method {set xlabel} {text} {
			set options(-xlabel) $text
			$self RedrawRequest
		}

		method {set ylabel} {text} {
			set options(-ylabel) $text
			$self RedrawRequest
		}

		method {set format} {axis args} {
			switch $axis {
				x  { upvar 0 options(-xformat) fmtvar }
				y  { upvar 0 options(-yformat) fmtvar }
				z  { upvar 0 options(-zformat) fmtvar }
				default { return -code error "Unknown axis $axis" }
			}
			switch [llength $args] {
				0 {
					# restore default
					set fmt %g
				}
				1 {
					# one argument = "format" formatstring
					set fmt [list numeric {*}$args]
				}
				2 {
					# two arguments = swap order for formatcmd
					lassign $args fmtstring type
					if {$type ni {command timedate numeric}} {
						return -code error "Unknown formatting procedure $type"
					}
					set fmt [list $type $fmtstring]
				}
				default {
					return -code error "Wrong # arguments ($args given): $self set format <axis> ?fmt? ?type?"
				}
			}
			set fmtvar $fmt
			$self RedrawRequest
		}

		method {set key} {args} {
			# no argument - just enable legend
			if {[llength $args]==0} {
				dict set options(-key) disabled false
				$self RedrawRequest
				return
			}
			# otherwise process args
			# The value "outside" means horizontal but outside the plot area
			# The value "outside-dummy" means "outside" but the option is only used to compute the right margin width for synchronized Bode plots
			foreach arg $args {
				switch $arg {
					top   -
					bottom { dict set options(-key) vertical $arg }
					right -
					left  { dict set options(-key) horizontal $arg }
					inside  -
					outside  -
					outside-dummy  { dict set options(-key) outside $arg }
					on  { dict set options(-key) disabled false }
					off  { dict set options(-key) disabled true }
					default { return -code error "Unknown option for set key: $arg" }
				}
			}
			$self RedrawRequest
		}


		proc parsemarkup {defaults args} {
			initparsearg $defaults
			parsearg {color lc} black
			parsearg {pointtype pt} ""
			parsearg {pointsize ps} 1.0
			parsearg {linewidth lw} 1.0
			parsearg {dash} ""
			parsearg {text t} ""
			parsearg {anchor} "c"
			parsearg {boxcolor} ""
			parsearg {boxlinewidth} 1.0
			parsearg {boxlinecolor} ""
			parsearg {boxdash} ""
			parsearg {padding} 5
			parsearg {data at} {}
			errorargs

			return [parsearg_asdict]

		}

		method {set label} {args} {
			#	?text ...?
			initparsearg
			parsearg {id} ""

			if {$id eq ""} {
				# create new markup id
				set id $datasetnr
				incr datasetnr
				set oldldata {}
			} else {
				# update existing id. Fist check, if it exists
				if {[dict exists $labeldata $id]} {
					set oldldata [dict get $labeldata $id]
				} else {
					# error
					return -code error "Unknown markup id $id"
				}
			}

			# parse the options
			set ldata [parsemarkup $oldldata {*}$args]
			dict set labeldata $id $ldata
			$self RedrawRequest
			return $id

		}

		method {highlight} {id dpnr args} {
			#	?text ...?

			initparsearg

			# update existing id. Fist check, if it exists
			if {![dict exists $plotdata $id]} {
				return -code error "Unknown dataset id $id"
			}

			if {[dict exists $plotdata $id highlight $dpnr]} {
				set oldldata [dict get $plotdata $id highlight $dpnr]
			} else {
				set oldldata {color red pointtype circles pointsize 1.5 linewidth 2}
			}

			set ldata [parsemarkup $oldldata {*}$args]
			dict set plotdata $id highlight $dpnr $ldata

			$self RedrawRequest
			return $id

		}

		method clearhighlight {ids} {
			if {$ids eq "all"} {
				set ids [$self getdatasetids]
			}

			foreach id $ids {
				dict unset plotdata $id highlight
			}
			$self RedrawRequest
		}

		method getdata {id args} {
			if {[dict exists $plotdata $id]} {
				return [dict get $plotdata $id {*}$args]
			}
		}

		method getstyle {id} {
			# create a description of the style used for plot id
			# in the form that can be passed to "plot" or "update"
			set dset [dict get $plotdata $id]
			set pt [dict exists $dset type points]
			set lt [dict exists $dset type lines]
			set result {}
			dict set result with [dict get {00 none 10 points 01 lines 11 linespoints} $pt$lt]
			dict set result color [dict get $dset color]
			dict set result linewidth [dict get $dset linewidth]
			dict set result dash [dict get $dset dash]
			if {$pt} {
				dict set result pointtype [dict get $dset pointtype]
				dict set result pointsize [dict get $dset pointsize]
			}
			
			return $result
		}

		method getdatasetids {} {
			dict keys $plotdata
		}
		
		method calcranges {} {
			# compute ranges spanned by data
			set datarange {}
			dict for {id data} $plotdata {
				if {[dict get $data type] eq {}} { continue }
				set datarange [combine_range $datarange [dict get $data datarange]]
			}

			set dxmin [lindex [dict get $datarange xmin] $options(-logx) $options(-logy)]
			set dxmax [lindex [dict get $datarange xmax] $options(-logx) $options(-logy)]
			set dymin [lindex [dict get $datarange ymin] $options(-logx) $options(-logy)]
			set dymax [lindex [dict get $datarange ymax] $options(-logx) $options(-logy)]
			set dzmin [lindex [dict get $datarange zmin] $options(-logz)]
			set dzmax [lindex [dict get $datarange zmax] $options(-logz)]

			# now compute range from request & data
			set xwiden {min false max false}
			set ywiden {min false max false}
			set zwiden {min false max false}
			lassign $options(-xrange) xmin xmax
			lassign $options(-yrange) ymin ymax
			lassign $options(-zrange) zmin zmax

			if {$xmin =="*" || ($options(-logx) && !islogfinite($xmin))} {
				set xmin $dxmin
				dict set xwiden min true
			}

			if {$ymin =="*" || ($options(-logy) && !islogfinite($ymin))} {
				set ymin $dymin
				dict set ywiden min true
			}

			if {$zmin =="*" || ($options(-logz) && !islogfinite($zmin))} {
				set zmin $dzmin
				dict set zwiden min true
			}

			if {$xmax =="*" || ($options(-logx) && !islogfinite($xmax))} {
				set xmax $dxmax
				dict set xwiden max true
			}

			if {$ymax =="*" || ($options(-logy) && !islogfinite($ymax))} {
				set ymax $dymax
				dict set ywiden max true
			}

			if {$zmax =="*" || ($options(-logz) && !islogfinite($zmax))} {
				set zmax $dzmax
				dict set zwiden max true
			}

			# now, we could still have an unusable range in case the data
			# doesn't provide us with a sensible range
			lassign [sanitize_range $xmin $xmax] xmin xmax
			lassign [sanitize_range $ymin $ymax] ymin ymax
			lassign [sanitize_range $zmin $zmax] zmin zmax
			
			# now we have the tight range in xmin,xmax, ymin, ymax
			# compute ticlists and round for data determined values
			lassign [compute_ticlist $xmin $xmax $options(-xtics) \
				$options(-logx) $xwiden [formatcmd $options(-xformat)]] xticlist xmin xmax

			lassign [compute_ticlist $ymin $ymax $options(-ytics) \
				$options(-logy) $ywiden [formatcmd $options(-yformat)]] yticlist ymin ymax

			lassign [compute_ticlist $zmin $zmax $options(-ztics) \
				$options(-logz) $zwiden [formatcmd $options(-zformat)]] zticlist zmin zmax

			set displayrange [dict create xmin $xmin xmax $xmax ymin $ymin ymax $ymax zmin $zmin zmax $zmax]

		}

		proc formatcmd {fmt} {
			# return a cmd prefix to convert
			# tic positions into strings
			if {[llength $fmt]<=1} {
				# single argument - use format
				return [list format {*}$fmt]
			}
			lassign $fmt type arg
			switch $type {
				command { return $arg }
				timedate { return [list apply {{fmt t}  {clock format [expr {entier($t)}] -format $fmt}} $arg] }
				numeric { return [list format $arg] }
				default { return -code error "Wrong tic format option" }
			}
			error "Shit happens"
		}

		method calcsize {} {
			# compute size of the plot area in pixels
			# such that it fits with all labels etc. into the canvas
			set w [winfo width $win]
			set h [winfo height $win]
			# width of xtic labels to the left and right
			set xmaxwidth [font measure $axisfont [lindex $xticlist end-1]]
			set xminwidth [font measure $axisfont [lindex $xticlist 0]]

			# maximum width of the ytic labels
			set lwidth 0
			foreach {text tic} $yticlist {
				set nw [font measure $axisfont $text]
				set lwidth [expr {max($lwidth, $nw)}]
			}

			set lascent [font metrics $axisfont -ascent]
			set ldescent [font metrics $axisfont -descent]
			set lineheight [font metrics $axisfont -linespace]

			set margin [expr {0.03*$w}]

			# Compute extra margin when legend is placed horizontaly outside of the plot area
			if {[dict get $options(-key) outside] != "inside"} {
				# Get longest legend text
				set titlemax ""
				foreach id $zstack {
					if {[dict exists $plotdata $id title]} {
						set title [dict get $plotdata $id title]
						if {[string length $title]>[string length $titlemax]} {
							set titlemax $title
						}
					}
				}
				# Get length of legend
				set extramargin [expr {[font measure $axisfont $titlemax] + $options(-samplelength)}]
			} else {
				set extramargin 0
			}

			# set left margin to have room for ytic labels + ylabel
			set deskxmin [expr {($lwidth+$options(-ticlength))+$margin}]
			if { $options(-ylabel) != "" } {
				set ylabelx [expr {$margin/2}]
				set deskxmin [expr {$deskxmin + 1.2 * $lineheight}]
			} else {
				set ylabelx 0
			}
			# if necessary, make space for first xtic
			set deskxmin [expr {max($deskxmin, 0.5*$xminwidth)}]
			set deskxmax [expr {$w-0.5*$xmaxwidth-$margin}]

			if {[dict get $options(-key) outside] != "inside"} {
				# make extra space for legend
				if {[dict get $options(-key) horizontal] == "left"} {
					set deskxmin [expr {$deskxmin + $extramargin}]
				} else {
					set deskxmax [expr {$deskxmax - $extramargin}]
				}
			}

			set deskymax [expr {max($options(-ticlength),$lascent)+$margin}]
			set deskymin [expr {($h-$options(-ticlength)-$lineheight-$ldescent)-$margin}]
			if { $options(-xlabel) != "" } {
				set xlabely [expr {$deskymin+$margin/2}]
				set deskymin [expr {$deskymin - 1.2 * $lineheight}]
			} else {
				set xlabely $deskymin
			}


			set displaysize [dict create xmin $deskxmin xmax $deskxmax ymin $deskymin ymax $deskymax \
				margin $margin xlabely $xlabely ylabelx $ylabelx]
		}

		# compute the transform from graph coordinates
		# to pixels
		method calctransform {} {
			set xmin [dict get $displayrange xmin]
			set xmax [dict get $displayrange xmax]
			set ymin [dict get $displayrange ymin]
			set ymax [dict get $displayrange ymax]
			set zmin [dict get $displayrange zmin]
			set zmax [dict get $displayrange zmax]

			set dxmin [dict get $displaysize xmin]
			set dxmax [dict get $displaysize xmax]
			set dymin [dict get $displaysize ymin]
			set dymax [dict get $displaysize ymax]

			if {$options(-logx)} {
				set xmin [cutoff_log $xmin]
				set xmax [cutoff_log $xmax]
			}

			lassign [compute_rangetransform \
					$xmin $xmax $dxmin $dxmax] xmul xadd

			if {$options(-logy)} {
				set ymin [cutoff_log $ymin]
				set ymax [cutoff_log $ymax]
			}

			lassign [compute_rangetransform \
					$ymin $ymax $dymin $dymax] ymul yadd

			if {$options(-logz)} {
				set zmin [cutoff_log $zmin]
				set zmax [cutoff_log $zmax]
			}

			# color gradients are normalized from 0 to 1
			lassign [compute_rangetransform \
					$zmin $zmax 0.0 1.0] zmul zadd

			set transform [list $xmul $xadd $ymul $yadd $zmul $zadd]
		}

		method graph2pix {coords} {
			# transform a list of coordinates to pixels
			lassign $transform xmul xadd ymul yadd
			set result {}

			set logcode {}
			if {$options(-logx)} { append logcode x }
			if {$options(-logy)} { append logcode y }
			switch $logcode {
				{} {
					foreach {x y} $coords {
						lappend result [expr {$x*$xmul+$xadd}] [expr {$y*$ymul+$yadd}]
					}
				}

				x {
					foreach {x y} $coords {
						lappend result [expr {($x<=0)? -Inf*$xmul : log($x)*$xmul+$xadd}] \
						[expr {$y*$ymul+$yadd}]
					}
				}

				y {
					foreach {x y} $coords {
						lappend result [expr {$x*$xmul+$xadd}] \
						[expr {($y<=0)? -Inf*$ymul : log($y)*$ymul+$yadd}]
					}
				}

				xy {
					foreach {x y} $coords {
						lappend result [expr {($x<=0)? -Inf*$xmul : log($x)*$xmul+$xadd}] \
						[expr {($y<=0)? -Inf*$ymul : log($y)*$ymul+$yadd}]
					}
				}
			}
			return $result
		}
		
		method ztocolor {zvalues name} {
			lassign $transform xmul xadd ymul yadd zmul zadd
			set map [getcolormap $name]

			if {$options(-logz)} {
				return [lmap z $zvalues \
					{getcolor $map [expr {($z<=0)? -Inf*$zmul : log($z)*$zmul+$zadd}]}]
			} else {
				return [lmap z $zvalues \
					{getcolor $map [expr {$z*$zmul+$zadd}]}]
			}
		}

		# convert a single value to/from graph coordinates
		method xToPix {x} {
			lassign $transform xmul xadd ymul yadd
			if {$options(-logx)} {
				expr {($x<=0)? -Inf*$xmul : log($x)*$xmul+$xadd}
			} else {
				expr {$x*$xmul+$xadd}
			}
		}

		method yToPix {y} {
			lassign $transform xmul xadd ymul yadd
			if {$options(-logy)} {
				expr {($y<=0) ? -Inf*$ymul : log($y)*$ymul+$yadd}
			} else {
				expr {$y*$ymul+$yadd}
			}
		}

		method pixToX {x} {
			lassign $transform xmul xadd ymul yadd
			if {$options(-logx)}  {
				expr {exp(($x-$xadd)/$xmul)}
			} else {
				expr {($x-$xadd)/$xmul}
			}
		}

		method pixToY {y} {
			lassign $transform xmul xadd ymul yadd
			if {$options(-logy)}  {
				expr {exp(($y-$yadd)/$ymul)}
			} else {
				expr {($y-$yadd)/$ymul}
			}
		}

		method getdisplayrange {args} {
			return $displayrange
		}

		method getdisplaysize {args} {
			return $displaysize
		}

		method drawdata {} {
			foreach id $zstack {
				# draw in correct order, dispatch between
				# lines and points
				if {[dict exists $plotdata $id type points]} {
					$self drawpoints $id
				}
				if {[dict exists $plotdata $id type lines]} {
					$self drawlines $id
				}
				if {[dict exists $plotdata $id highlight]} {
					$self drawhighlight $id
				}
			}

			$self drawmarkup
		}

		method drawpoints {id} {
			set data [dict get $plotdata $id data]
			
			if {[dict get $plotdata $id varying] == "color"} {
 				set zdata [dict get $plotdata $id zdata]
				lassign [geometry::pointclipz $data $zdata $displayrange] clipdata clipzdata clipinfo
				set colorcode true
			} else {
				lassign [geometry::pointclip $data $displayrange] clipdata clipinfo
				set colorcode false
			}
			
			# store away the clipped & transformed data
			# together with the info of the clipping
			# needed for picking points
			dict set plotdata $id clipinfo $clipinfo
			set transdata [$self graph2pix $clipdata]
			dict set plotdata $id transdata $transdata

			set shapeproc shape-[dict get $plotdata $id pointtype]
			
			if {$colorcode} {
				set varying color
				lappend varying [$self ztocolor $clipzdata [dict get $plotdata $id colormap]]
			} else {
				set varying {}
			}
			
			$shapeproc $hull $transdata \
				[dict get $plotdata $id color] \
				[dict get $plotdata $id pointsize]	\
				[dict get $plotdata $id linewidth]	\
				[dict get $plotdata $id dash]	\
			    $varying \
				$selfns
		}

		method drawlines {id} {
			set data [dict get $plotdata $id data]
			set color [dict get $plotdata $id color]
			set width [dict get $plotdata $id linewidth]
			set dash [dict get $plotdata $id dash]

			set piece {}
			set pieces {}
			foreach {x y} $data {
				if {isnan($x) || isnan($y)} {
					# NaN value, start a new piece
					if {[llength $piece]>0} {
						lappend pieces [$self graph2pix $piece]
					}
					set piece {}
					continue
				}

				lappend piece $x $y
			}


			lappend pieces [$self graph2pix $piece]

			set ids {}
			foreach piece $pieces {
				if {[llength $piece]>=4} {
					set clipped [geometry::polylineclip $piece $displaysize]
					foreach coord $clipped {
						if {[llength $coord]<4} {
							# error
							puts "Input coords: "
							puts "set piece [list $piece]"
							puts "ukaz::geometry::polylineclip {$piece} $displaysize"
							error "polyline did wrong, look in console"
						}
						lappend ids [$hull create line $coord \
							-fill $color -width $width -tag $selfns -dash $dash]
					}
				}
			}
			return $ids
		}

		method drawmarkuppoint {coords style} {
			# draw a single label with text in a box
			# and a data point symbol

			lassign [geometry::pointclip $coords $displayrange] clipdata clipinfo
			set transdata [$self graph2pix $clipdata]
			if {[llength $transdata] != 2} return

			lassign $transdata x y

			dict with style {
				if {$text ne ""} {
					set tid [$hull create text $x $y \
						-fill $color -anchor $anchor \
						-tag $selfns -font $labelfont -text $text]

					if {$boxcolor ne "" || $boxlinecolor ne ""} {
						# compute size of the box
						set bbox [$hull bbox $tid]
						# enlarge by padding
						lassign $bbox x1 y1 x2 y2

						set x1o [expr {$x1-$padding}]
						set x2o [expr {$x2+$padding}]
						set y1o [expr {$y1-$padding}]
						set y2o [expr {$y2+$padding}]

						$hull create rectangle $x1o $y1o $x2o $y2o \
							-fill $boxcolor -outline $boxlinecolor -dash $boxdash \
							-width $boxlinewidth -tag $selfns

						$hull raise $tid
					}

				}

				if {$pointtype ne ""} {
					set shapeproc shape-$pointtype
					$shapeproc $hull $transdata \
						$color \
						$pointsize	\
						$linewidth	\
						$dash \
						{} $selfns
				}

			}
		}


		method drawmarkup {} {
			dict for {id ldata} $labeldata {
				$self drawmarkuppoint [dict get $ldata data] $ldata
			}
		}

		method drawhighlight {id} {
			set highlights [dict get $plotdata $id highlight]
			set pdata [dict get $plotdata $id data]

			dict for {dpnr ldata} $highlights {
				set xp [lindex $pdata [expr {2*$dpnr}]]
				set yp [lindex $pdata [expr {2*$dpnr+1}]]
				set coords [list $xp $yp]

				$self drawmarkuppoint $coords $ldata
			}
		}


		method drawlegend {} {
			# check if legend is enabled
			if {[dict get $options(-key) disabled]} {
				return
			}
			# check if legend is dummy
			if {[dict get $options(-key) outside]=="outside-dummy"} {
				return
			}
			# draw the titles and a sample
			set lineheight [expr {[font metrics $axisfont -linespace]*$options(-keyspacing)}]

			# create list of all ids that have titles and a plot style
			# in correct zstack order
			set titleids {}
			foreach id $zstack {
				if {[dict get $plotdata $id type] eq {}} { continue }

				if {[dict exists $plotdata $id title]} {
					set title [dict get $plotdata $id title]
					if {$title != ""} { lappend titleids $id }
				}
			}
			# compute size needed for legend

			set dxmin [dict get $displaysize xmin]
			set dymin [dict get $displaysize ymin]
			set dxmax [dict get $displaysize xmax]
			set dymax [dict get $displaysize ymax]

			set totalheight [expr {[llength $titleids]*$lineheight}]
			set yoffset $lineheight ;# one line distance from border
			set xoffset [expr {$options(-samplelength)/4}] ;# 1/4 length distance from border

			# y position of top sample
			if {[dict get $options(-key) vertical]=="top"} {
				set y0 [expr {$dymax+$yoffset}]
			} else {
				# bottom
				set y0 [expr {$dymin-$totalheight}]
			}

			# x coordinates of line, sample and text anchor
			if {[dict get $options(-key) outside]=="inside"} {
				# place key inside
				if {[dict get $options(-key) horizontal]=="left"} {
					# inside left
					set x0 [expr {$dxmin+$xoffset}]
					set x1 [expr {$dxmin+$xoffset+$options(-samplelength)}]
					set sx [expr {($x0+$x1)/2}]
					set tx [expr {$x1+$xoffset}]
					set anchor w
				} elseif {[dict get $options(-key) horizontal]=="right"} {
					# inside right
					set x0 [expr {$dxmax-$xoffset-$options(-samplelength)}]
					set x1 [expr {$dxmax-$xoffset}]
					set sx [expr {($x0+$x1)/2}]
					set tx [expr {$x0-$xoffset}]
					set anchor e
				}
			} else {
				# place key outside
				if {[dict get $options(-key) horizontal]=="left"} {
					# outside left
					set x0 [expr {$xoffset}]
					set x1 [expr {$xoffset+$options(-samplelength)}]
					set sx [expr {($x0+$x1)/2}]
					set tx [expr {$x1+$xoffset}]
					set anchor w
				} else {
					# outside right
					set x0 [expr {$dxmax+$xoffset+$options(-samplelength)}]
					set x1 [expr {$dxmax+$xoffset}]
					set sx [expr {($x0+$x1)/2}]
					set tx [expr {$x0+$xoffset}]
					set anchor w
				}
			}

			# draw !
			set ycur $y0
			foreach id $titleids {
				set title [dict get $plotdata $id title]
				if {[dict exists $plotdata $id type points]} {
					set shapeproc shape-[dict get $plotdata $id pointtype]
					$shapeproc $hull [list $sx $ycur] \
						[dict get $plotdata $id color] \
						[dict get $plotdata $id pointsize]	\
						[dict get $plotdata $id linewidth]	\
						[dict get $plotdata $id dash]	\
						{} $selfns
				}

				if {[dict exists $plotdata $id type lines]} {
					$hull create line [list $x0 $ycur $x1 $ycur] \
							-fill [dict get $plotdata $id color] \
							-width [dict get $plotdata $id linewidth] \
							-dash [dict get $plotdata $id dash] -tag $selfns
				}

				$hull create text $tx $ycur \
					-anchor $anchor  \
					-text $title -font $axisfont -tag $selfns
				# advance
				set ycur [expr {$ycur+$lineheight}]
			}

		}

		method drawcoordsys {} {
			set dxmin [dict get $displaysize xmin]
			set dymin [dict get $displaysize ymin]
			set dxmax [dict get $displaysize xmax]
			set dymax [dict get $displaysize ymax]
			# draw border
			$hull create rectangle $dxmin $dymin $dxmax $dymax -tag $selfns
			# draw xtics
			foreach {text xval} $xticlist {
				set deskx [$self xToPix $xval]
				if { $options(-grid) } {
					$hull create line $deskx $dymin $deskx $dymax -fill gray -tag $selfns
				}
				$hull create line $deskx $dymin  $deskx [expr {$dymin+$options(-ticlength)}] -tag $selfns
				$hull create text $deskx [expr {$dymin+$options(-ticlength)}] \
					-anchor n -justify center \
					-text $text -font $axisfont -tag $selfns
			}

			# draw ytics
			foreach {text yval} $yticlist {
				set desky [$self yToPix $yval]
				if { $options(-grid) } {
					$hull create line $dxmin $desky $dxmax $desky -fill gray -tag $selfns
				}
				$hull create line $dxmin $desky  [expr {$dxmin-$options(-ticlength)}] $desky -tag $selfns
				$hull create text  [expr {$dxmin-$options(-ticlength)}] $desky \
					-anchor e -justify right \
					-text $text -font $axisfont -tag $selfns
			}

			# draw xlabel and ylabel
			if {$options(-xlabel) != {}} {
					set xcenter [expr {($dxmin + $dxmax) / 2}]
					set ypos [dict get $displaysize xlabely]
					$hull create text $xcenter $ypos -anchor n \
						-text $options(-xlabel) -font $axisfont -tag $selfns
			}

			if {$options(-ylabel) != {}} {
				set ycenter [expr {($dymin + $dymax) / 2}]
				set xpos [dict get $displaysize ylabelx]
				$hull create text $xpos  $ycenter -anchor n \
					-angle 90 -text $options(-ylabel) -font $axisfont -tag $selfns
			}

		}

		method canv {args} {
			$hull {*}$args
		}

		method Redraw {} {
			# puts "Now drawing [$self configure]"
			if {[dict size $plotdata] == 0} { return }
			$self calcranges
			$self calcsize
			$self calctransform

			# strange effect: after everything is deleted from the canvas
			# font metrics takes 100x longer due to caching
			$hull delete $selfns
			$self drawcoordsys
			$self drawdata
			$self drawlegend
			incr options(-redraw)
			# notify embedded controls
			set errors {}
			foreach c $controls {
				if {[catch {$c Configure $displaysize} err errdict]} {
					lappend errors [dict get $errdict -errorinfo]
				}
			}
			if {[llength $errors] > 0} {
				# rethrow errors
				return -code error [join $errors \n]

			}
		}

		method clear {} {
			set plotdata {}
			set labeldata {}
			set zstack {}
			set datasetnr 0
			$self RedrawRequest
		}

		method fontset {option value} {
			# when -font is set, create the font
			# possibly delete the old one

			# let error propagate from here, before accepting the setting
			set newfont [font create {*}$value]

			if {$options(-font) != {}} {
				font delete $axisfont
			}
			set axisfont $newfont
			set options(-font) $value
			$self RedrawRequest
		}

		method rangeset {option value} {
			# configuremethod for -xrange, -yrange
			# first check validity
			lassign $value from to
			if {(isfinite($from) || $from == "*") &&
				(isfinite($to) || $to == "*")} {
				set options($option) [list $from $to]
				set zoomstack {}
				$self RedrawRequest
			} else {
				return -code error "Range limits must be either a float or *"
			}
		}

		method zoomin {range} {
			# store current range in zoomstack
			lappend zoomstack [list $options(-xrange) $options(-yrange)]
			# apply zoom range
			lassign $range xmin xmax ymin ymax
			set options(-xrange) [list $xmin $xmax]
			set options(-yrange) [list $ymin $ymax]
			$self RedrawRequest
			event generate $win <<Zoom>> -data $range
		}

		method zoomout {} {
			if {[llength $zoomstack] > 0} {
				set range [lindex $zoomstack end]
				set zoomstack [lrange $zoomstack 0 end-1]
				lassign $range options(-xrange) options(-yrange)
				$self RedrawRequest
				event generate $win <<Zoom>> -data [concat $range]
			}
		}

		#### Methods for dragging rectangles (for zooming) #####
		method {drag start} {x y} {
			# try to see if this is our object
			set cid [$hull find withtag current]
			# only for empty result or an object tagged with
			# $selfns, start action
			if {$cid == {} || $selfns in [$hull gettags $cid]} {
				dict set dragdata clicking true
				dict set dragdata dragging false
				dict set dragdata x0 $x
				dict set dragdata y0 $y
			}
		}

		method {drag move} {x y} {
			if {[dict get $dragdata dragging]} {
				$hull coords dragrect \
					[dict get $dragdata x0] [dict get $dragdata y0] $x $y
			}

			if {[dict get $dragdata clicking]} {
				# user has moved mouse - it's dragging now
				# not clicking
				$hull create rectangle $x $y $x $y -fill "" -outline red -tag dragrect
				dict set dragdata clicking false
				dict set dragdata dragging true
			}
			# if nothing is set in dragdata, it's not our business
		}

		method {drag end} {x y s} {
			# user has released mouse button
			# check if it was a click or a drag (zoom)
			if {[dict get $dragdata clicking]} {
				# inverse transform this point
				set xgraph [$self pixToX $x]
				set ygraph [$self pixToY $y]
				event generate $win <<Click>> -x $x -y $y -state $s -data [list $xgraph $ygraph]
			}

			if {[dict get $dragdata dragging]} {
				# inverse transform both coordinates
				set x1 [$self pixToX $x]
				set y1 [$self pixToY $y]
				set x0 [$self pixToX [dict get $dragdata x0]]
				set y0 [$self pixToY [dict get $dragdata y0]]
				# remove drag rectangle
				$hull delete dragrect
				# check for correct ordering
				if {$x1 < $x0} { lassign [list $x0 $x1] x1 x0 }
				if {$y1 < $y0} { lassign [list $y0 $y1] y1 y0 }

				if {$x0 != $x1 && $y0 != $y1} {
					# zoom in!
					$self zoomin [list $x0 $x1 $y0 $y1]
				}
			}
			dict set dragdata dragging false
			dict set dragdata clicking false
		}

		method motionevent {x y} {
			# inverse transform this point
			set xgraph [$self pixToX $x]
			set ygraph [$self pixToY $y]
			event generate $win <<MotionEvent>> -x $x -y $y -data [list $xgraph $ygraph]
		}

		method pickpoint {x y {maxdist 5}} {
			# identify point in dataset given by *screen coordinates* x,y
			# maximum distance from center maxdist
			# return the topmost datapoint nearer than maxdist
			set maxdistsq [expr {$maxdist**2}]
			foreach id [lreverse $zstack] {
				if {[dict exists $plotdata $id transdata]} {
					# the transformed data is only available after drawing
					set transdata [dict get $plotdata $id transdata]
					set clipinfo [dict get $plotdata $id clipinfo]
					set mindistsq Inf
					set nr 0
					foreach {xp yp} $transdata {
						set distsq [expr {($xp-$x)**2+($yp-$y)**2}]
						if {$distsq<$mindistsq} {
							set mindistsq $distsq
							set minnr $nr
						}
						incr nr
					}

					if {$mindistsq < $maxdistsq} {
						# now compute the real datapointnr after clipping
						set dpnr $minnr
						foreach {clipnr cliplength} $clipinfo {
							if {$clipnr <= $minnr} {
								incr dpnr $cliplength
							}
						}
						# get the original data
						set data [dict get $plotdata $id data]
						set xd [lindex $data [expr {$dpnr*2}]]
						set yd [lindex $data [expr {$dpnr*2+1}]]

						# short circuiting ensures the 1st, topmost point is returned
						return [list $id $dpnr $xd $yd]
					}
				}
			}

			return {}
		}


		method saveAsPDF {fn} {
			package require pdf4tcl
			set size [list [winfo width $win] [winfo height $win]]
			set pdf [pdf4tcl::new %AUTO% -paper $size -compress false]
			$pdf canvas $hull
			$pdf write -file $fn
			$pdf destroy
		}

		variable controlFocus {}
		method addcontrol {c} {
			# add the control object c to the list of managed
			# objects. First send a Parent command to notify it
			$c Parent $self $hull
			lappend controls $c
			# get notification if this thing is deleted
			trace add command $c delete [mymethod controldeleted $c]
			# during Redraw it'll get a Configure request
			$self RedrawRequest
		}

		method removecontrol {c} {
			if {[lsearch -exact $controls $c]>=0} {
				set controls [lremove $controls $c]
				# remove the delete trace
				trace remove command $c delete [mymethod controldeleted $c]
				$c Parent {} {}
			}
		}

		method controldeleted {c args} {
			# the control was deleted from outside. Remove
			# from our list without executing anything
			if {[lsearch -exact $controls $c]>=0} {
				set controls [lremove $controls $c]
				if {$controlFocus eq $c} {
					set controlFocus {}
				}
			}
		}

		method controlClicked {which} {
			if {$controlFocus ne $which && $controlFocus ne {}} {
				$controlFocus FocusOut
			}
			$which FocusIn
			set controlFocus $which
		}

		method getSelectedControl {} {
			return $controlFocus
		}
	}


	snit::type dragline {
		variable dragging

		option -command -default {}
		option -orient -default horizontal -configuremethod SetOrientation
		option -variable -default {} -configuremethod SetVariable
		option -color -default {gray}

		variable pos
		variable canv {}
		variable graph {}
		variable xmin
		variable xmax
		variable ymin
		variable ymax

		variable loopescape false
		variable commandescape false

		constructor {args} {
			$self configurelist $args
		}

		destructor {
			$self untrace
			if { [info commands $canv] != {} } { $canv delete $selfns }
		}

		method Parent {parent canvas} {
			if {$parent != {}} {
				# this control is now managed
				if {$graph != {}} {
					return -code error "$self: Already managed by $graph"
				}

				if {[info commands $canvas] == {}} {
					return -code error "$self: No drawing canvas: $canv"
				}

				set graph $parent
				set canv $canvas

				$canv create line {-1 -1 -1 -1} -fill $options(-color) -dash . -tag $selfns
				# Bindings for dragging
				$canv bind $selfns <ButtonPress-1> [mymethod dragstart %x %y]
				$canv bind $selfns <Motion> [mymethod dragmove %x %y]
				$canv bind $selfns <ButtonRelease-1> [mymethod dragend %x %y]

				# Bindings for hovering - change cursor
				$canv bind $selfns <Enter> [mymethod dragenter]
				$canv bind $selfns <Leave> [mymethod dragleave]

				set dragging 0

			} else {
				# this control was unmanaged. Remove our line
				if {$canv != {} && [info commands $canv] != {}} {
					$canv delete $selfns
				}
				set graph {}
				set canv {}
			}
		}

		method Configure {range} {
			# the plot range has changed
			set loopescape false

			set xmin [dict get $range xmin]
			set xmax [dict get $range xmax]
			set ymin [dict get $range ymin]
			set ymax [dict get $range ymax]

			set loopescape false
			set commandescape true
			$self SetValue
		}

		method SetVariable {option varname} {
			$self untrace
			if {$varname != {}} {
				upvar #0 $varname v
				trace add variable v write [mymethod SetValue]
				set options(-variable) $varname
				$self SetValue
			}
		}

		method untrace {} {
			if {$options(-variable)!={} } {
				upvar #0 $options(-variable) v
				trace remove variable v write [mymethod SetValue]
				set options(-variable) {}
			}
		}

		method SetValue {args} {
			if {$loopescape} {
				set loopescape false
				return
			}
			set loopescape true
			upvar #0 $options(-variable) v
			if {[info exists v]} {
				catch {$self gotoCoords $v $v}
				# ignore any errors if the graph is incomplete
			}
		}

		method DoTraces {} {
			if {$loopescape} {
				set loopescape false
			} else {
				if {$options(-variable)!={}} {
					set loopescape true
					upvar #0 $options(-variable) v
					set v $pos
				}
			}

			if {$options(-command)!={}} {
				if {$commandescape} {
					set commandescape false
				} else {
					uplevel #0 [list {*}$options(-command) $pos]
				}
			}
		}

		method SetOrientation {option value} {
			switch $value {
				vertical  -
				horizontal {
					set options($option) $value
				}
				default {
					return -code error "Unknown orientation $value: must be vertical or horizontal"
				}
			}
		}

		method dragenter {} {
			if {!$dragging} {
				$canv configure -cursor hand2
			}
		}

		method dragleave {} {
			if {!$dragging} {
				$canv configure -cursor {}
			}
		}

		method dragstart {x y} {
			set dragging 1
		}

		method dragmove {x y} {
			if {$dragging} {
				$self GotoPixel $x $y
			}
		}

		method dragend {x y} {
			set dragging 0
		}

		method GotoPixel {x y} {
			if {$graph=={}} { return }
			set rx [$graph pixToX $x]
			set ry [$graph pixToY $y]
			if {$options(-orient)=="horizontal"} {
				set pos $ry
				$canv coords $selfns [list $xmin $y $xmax $y]
			} else {
				set pos $rx
				$canv coords $selfns [list $x $ymin $x $ymax]
			}
			$self DoTraces
		}

		method gotoCoords {x y} {
			if {$graph=={}} { return }

			lassign [$graph graph2pix [list $x $y]] nx ny
			if {$options(-orient)=="horizontal"} {
				set pos $y
				$canv coords $selfns [list $xmin $ny $xmax $ny]
			} else {
				set pos $x
				$canv coords $selfns [list $nx $ymin $nx $ymax]
			}
			$canv raise $selfns
			$self DoTraces
		}

		method gotoRel {p} {
			# move the line to the ratio p of the graph on screen
			set x [expr {$xmin + ($xmax - $xmin)*$p}]
			set y [expr {$ymin + ($ymax - $ymin)*$p}]
			$self GotoPixel $x $y
		}
	}

	# GUI control to define a region of interest (min/max)
	snit::type dragregion {
		variable dragging
		variable dragpos

		option -command -default {}
		option -orient -default vertical -configuremethod SetOrientation
		option -label -default {} -configuremethod SetOption

		option -minvariable -default {} -configuremethod SetVariable
		option -maxvariable -default {} -configuremethod SetVariable

		option -color -default {#FF3030} -configuremethod SetColor
		option -fillcolor -default {#FFB0B0} -configuremethod SetOption

		variable pos {}
		variable pixpos
		variable pcenter
		variable canv {}
		variable graph {}
		variable xmin
		variable xmax
		variable ymin
		variable ymax

		variable loopescape false
		variable commandescape false

		constructor {args} {
			$self configurelist $args
		}

		destructor {
			$self untrace -minvariable
			$self untrace -maxvariable
			if { [info commands $canv] != {} } {
				$canv delete $selfns.min
				$canv delete $selfns.max
				$canv delete $selfns.region
				$canv delete $selfns.text
			}
		}

		proc fadecolor {color alpha} {
			# blend a color with white
			scan $color {#%02x%02x%02x} r g b
			set R [expr {int(255*(1-$alpha) + $r*$alpha)}]
			set G [expr {int(255*(1-$alpha) + $g*$alpha)}]
			set B [expr {int(255*(1-$alpha) + $b*$alpha)}]
			format {#%02X%02X%02X} $R $G $B
		}

		method Parent {parent canvas} {
			if {$parent != {}} {
				# this control is now managed
				if {$graph != {}} {
					return -code error "$self: Already managed by $graph"
				}

				if {[info commands $canvas] == {}} {
					return -code error "$self: No drawing canvas: $canv"
				}

				set graph $parent
				set canv $canvas

				$canv create line {-1 -1 -1 -1} -fill $options(-color) -dash {6 4} -tag $selfns.min
				$canv create line {-1 -1 -1 -1} -fill $options(-color) -dash {6 4} -tag $selfns.max
				$canv create rectangle -2 -2 -1 -1 -outline "" -fill $options(-fillcolor) -tag $selfns.region
				$canv lower $selfns.region

				$canv create text {-2 -2} -text $options(-label) -fill $options(-color) -tag $selfns.text
				if {$options(-orient) eq "vertical"} {
					$canv itemconfigure $selfns.text -angle 90
				}

				# Bindings for dragging
				$canv bind $selfns.min <ButtonPress-1> [mymethod dragstart min %x %y]
				$canv bind $selfns.min <Motion> [mymethod dragmove min %x %y]
				$canv bind $selfns.min <ButtonRelease-1> [mymethod dragend min %x %y]

				$canv bind $selfns.max <ButtonPress-1> [mymethod dragstart max %x %y]
				$canv bind $selfns.max <Motion> [mymethod dragmove max %x %y]
				$canv bind $selfns.max <ButtonRelease-1> [mymethod dragend max %x %y]

				$canv bind $selfns.region <ButtonPress-1> [mymethod dragstart region %x %y]
				$canv bind $selfns.region <Motion> [mymethod dragmove region %x %y]
				$canv bind $selfns.region <ButtonRelease-1> [mymethod dragend region %x %y]

				$canv bind $selfns.text <ButtonPress-1> [mymethod dragstart region %x %y]
				$canv bind $selfns.text <Motion> [mymethod dragmove region %x %y]
				$canv bind $selfns.text <ButtonRelease-1> [mymethod dragend region %x %y]

				# Bindings for hovering - change cursor
				$canv bind $selfns.min <Enter> [mymethod dragenter min]
				$canv bind $selfns.min <Leave> [mymethod dragleave]
				$canv bind $selfns.max <Enter> [mymethod dragenter max]
				$canv bind $selfns.max <Leave> [mymethod dragleave]
				$canv bind $selfns.region <Enter> [mymethod dragenter region]
				$canv bind $selfns.region <Leave> [mymethod dragleave]

				set dragging {}
				set dragpos {}

			} else {
				# this control was unmanaged. Remove our line
				if {$canv != {} && [info commands $canv] != {}} {
					$canv delete $selfns
				}
				set graph {}
				set canv {}
			}
		}

		variable configured false

		method Configure {range} {
			# the plot range has changed
			set loopescape false

			set xmin [dict get $range xmin]
			set xmax [dict get $range xmax]
			set ymin [dict get $range ymin]
			set ymax [dict get $range ymax]

			set configured true

			set loopescape false
			set commandescape true
			$self Redraw
		}

		method SetVariable {option varname} {
			$self untrace $option
			if {$varname != {}} {
				upvar #0 $varname v
				trace add variable v write [mymethod SetValue]
				set options($option) $varname
				$self SetValue
			}
		}

		method untrace {option} {
			if {$options($option)!={} } {
				upvar #0 $options($option) v
				trace remove variable v write [mymethod SetValue]
				set options($option) {}
			}
		}

		method SetValue {args} {
			if {$loopescape} {
				set loopescape false
				return
			}
			upvar #0 $options(-minvariable) vmin
			upvar #0 $options(-maxvariable) vmax
			if {[info exists vmin] && [info exists vmax]} {
				set loopescape true
				catch {$self setPosition $vmin $vmax} err
				# ignore any errors if the graph is incomplete
			}
		}

		method DoTraces {} {
			if {$loopescape} {
				set loopescape false
			} else {
				if {$options(-minvariable) ne {} && $options(-maxvariable) ne {}} {
					set loopescape true
					upvar #0 $options(-minvariable) vmin
					upvar #0 $options(-maxvariable) vmax
					lassign $pos vmin vmax
				}
			}

			if {$options(-command)!={}} {
				if {$commandescape} {
					set commandescape false
				} else {
					uplevel #0 [list {*}$options(-command) {*}$pos]
				}
			}
		}

		method SetOrientation {option value} {
			switch $value {
				vertical  {
					set options($option) $value
				}
				horizontal {
					set options($option) $value
				}
				default {
					return -code error "Unknown orientation $value: must be vertical or horizontal"
				}
			}
			$self Redraw
		}

		method SetOption {option value} {
			set options($option) $value
			$self Redraw
		}

		method SetColor {option color} {
			set options($option) $color
			set options(-fillcolor) [fadecolor $color 0.2]
			$self Redraw
		}

		method FocusIn {} {
			$canv itemconfigure $selfns.min -width 3 -dash {6 4}
			$canv itemconfigure $selfns.max -width 3 -dash {6 4}
		}

		method FocusOut {} {
			$canv itemconfigure $selfns.min -width 1 -dash {6 4}
			$canv itemconfigure $selfns.max -width 1 -dash {6 4}
		}

		method dragenter {what} {
			if {$dragging eq {}} {
				set cursor [dict get {
					vertical {min hand2 max hand2 region sb_h_double_arrow}
					horizontal {min hand2 max hand2 region sb_v_double_arrow}
					} $options(-orient) $what]
				$canv configure -cursor $cursor
			}
		}

		method dragleave {} {
			if {$dragging eq {}} {
				$canv configure -cursor {}
			}
		}

		method dragstart {what x y} {
			set dragging $what
			set dragpos [list $x $y {*}$pixpos]

			$graph controlClicked $self
		}

		method dragmove {what x y} {
			if {$dragging ne {}} {
				if {$what in {min max}} {
					$self GotoPixel $dragging $x $y
				} else {
					$self MoveRegion $x $y
				}
			}
		}

		method dragend {what x y} {
			set dragging {}
		}

		method GotoPixel {what px py} {
			if {$graph=={}} { return }

			lassign $pos vmin vmax
			lassign $pixpos pmin pmax

			set vx [$graph pixToX $px]
			set vy [$graph pixToY $py]

			if {$options(-orient) eq "horizontal"} {
				if {$what eq "min"} {
					set vmin $vy
					set pmin $py
				} else {
					set vmax $vy
					set pmax $py
				}
			} else {
				if {$what eq "min"} {
					set vmin $vx
					set pmin $px
				} else {
					set vmax $vx
					set pmax $px
				}

			}

			set pcenter [expr {($pmin + $pmax)/2}]
			set pixpos [list $pmin $pmax]
			set pos [list $vmin $vmax]

			$self drawregion
			$self DoTraces
		}

		method gotoRel {pmin pmax} {
			# move the region to the ratio p(min|max) of the graph on screen
			set minx [expr {$xmin + ($xmax - $xmin)*$pmin}]
			set miny [expr {$ymin + ($ymax - $ymin)*$pmin}]
			$self GotoPixel min $minx $miny

			set maxx [expr {$xmin + ($xmax - $xmin)*$pmin}]
			set maxy [expr {$ymin + ($ymax - $ymin)*$pmin}]
			$self GotoPixel max $maxx $maxy
		}

		method MoveRegion {px py} {
			lassign $dragpos startpx startpy startpmin startpmax

			if {$options(-orient) eq "vertical"} {
				set pxmin [expr {$startpmin + $px - $startpx}]
				set pxmax [expr {$startpmax + $px - $startpx}]
				set pymin $py
				set pymax $py
			} else {
				set pymin [expr {$startpmin + $py - $startpy}]
				set pymax [expr {$startpmax + $py - $startpy}]
				set pxmin $px
				set pxmax $px
			}
			$self GotoPixel min $pxmin $pymin
			$self GotoPixel max $pxmax $pymax
		}

		method setPosition {vmin vmax} {
			set pos [list $vmin $vmax]
			$self Redraw
		}

		method Redraw {} {

			if {$graph=={}} { return }

			lassign $pos vmin vmax
			if {$vmin eq {} || $vmax eq {}} { return }

			lassign [$graph graph2pix [list $vmin $vmin]] nxmin nymin
			lassign [$graph graph2pix [list $vmax $vmax]] nxmax nymax

			if {$options(-orient) eq "horizontal"} {
				set pmin $nymin
				set pmax $nymax
			} else {
				set pmin $nxmin
				set pmax $nxmax
			}

			set pcenter [expr {($pmin + $pmax)/2}]
			set pixpos [list $pmin $pmax]
			$self drawregion
			$self DoTraces
		}

		method drawregion {} {
			if {!$configured} { return }

			lassign $pixpos pmin pmax

			$canv itemconfigure $selfns.text -text $options(-label)
			#	puts "pos: $pos pixpos: $pixpos"

			if {$options(-orient)=="horizontal"} {
				$canv coords $selfns.min [list $xmin $pmin $xmax $pmin]
				$canv coords $selfns.max [list $xmin $pmax $xmax $pmax]
				$canv coords $selfns.region [list $xmin $pmin $xmax $pmax]
				set left [expr {$xmin*0.95 + $xmax*0.05}]
				$canv coords $selfns.text [list $left $pcenter]
				$canv itemconfigure $selfns.text -angle 0 -anchor w
			} else {
				$canv coords $selfns.min [list $pmin $ymin $pmin $ymax]
				$canv coords $selfns.max [list $pmax $ymin $pmax $ymax]
				$canv coords $selfns.region [list $pmin $ymin $pmax $ymax]
				set top [expr {$ymin*0.05 + $ymax*0.95}]
				$canv coords $selfns.text [list $pcenter $top]
				$canv itemconfigure $selfns.text -angle 90 -anchor e
			}

			$canv itemconfigure $selfns.min -fill $options(-color)
			$canv itemconfigure $selfns.max -fill $options(-color)
			$canv itemconfigure $selfns.region -fill $options(-fillcolor)
			$canv itemconfigure $selfns.text -fill $options(-color)

			$canv raise $selfns.min
			$canv raise $selfns.max
		}

		method getPosition {} {
			return $pos
		}

	}


	proc ::tcl::mathfunc::isfinite {x} {
		# determine, whether x,y is a valid point
		expr {[string is double -strict $x] && $x < Inf && $x > -Inf}
	}

	proc ::tcl::mathfunc::islogfinite {x} {
		# determine, whether x,y is a valid point on the logscale
		expr {[string is double -strict $x] && $x < Inf && $x > 0}
	}

	proc ::tcl::mathfunc::isnan {x} {
		expr {$x != $x}
	}

}
