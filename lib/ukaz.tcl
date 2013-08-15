package require snit
package require Tk 8.6
package provide ukaz 2.0a1

namespace eval ukaz {
	
	variable ns [namespace current]

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
			expr {abs($x) == Inf && abs($y) == Inf}
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
	proc calcdatarange {data}  {
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
		dict create xmin $xmin ymin $ymin xmax $xmax ymax $ymax	
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
		return $result
	}

	proc compute_rangetransform {r1min r1max r2min r2max} {
		set mul [expr {($r2max - $r2min)/($r1max -$r1min)}]
		set add [expr {$r2min-$r1min*$mul}]
		list $mul $add
	}

	############ Function for automatic axis scaling ##########
	proc compute_ticlist {min max tics log widen format} {
		# automatically compute sensible values
		# for the tics position, if not requested otherwise
		lassign $tics ticrequest spec
		switch $ticrequest {
			off {
				return [list {} $min $max]
			}

			list {
				# take the tics as they are
				# list must be text, number,...
				# don't widen
				return [list $spec $min $max]
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

					set expmin [expr {int(floor(log10($min)))}]
					set expmax [expr {int(floor(log10($max)))}]
					
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
								lappend ticlist [format $format $tic] $tic
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
								lappend ticlist [format $format $tic] $tic
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
			set start [expr {int(floor(double($min)/double($ticbase)))}]
			set min [expr {$ticbase*$start}]
		} else {
			set start [expr {int(ceil(double($min)/double($ticbase)))}]
		}
		
		if {[dict get $widen max]} {
			set stop [expr {int(ceil(double($max)/double($ticbase)))}]
			set max [expr {$ticbase*$stop}]
		} else {
			set stop [expr {int(floor(double($max)/double($ticbase)))}]
		}

		set ticlist {}
		for {set i $start} {$i<=$stop} {incr i} {
			set v [expr {$i*$ticbase}]
			# if {$log && $v<=0} { continue }
			lappend ticlist [format $format $v] $v
		}
		return [list $ticlist $min $max]		
	}

	######### Functions for parsing gnuplot style commands ###########
	proc parsearg {option default} {
		# read argument from args, set to default
		# if unset in args. option can have alternative
		# names
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
		if {!$success} { set resvar $default }
	}

	########### Functions for drawing marks on a canvas ##############
	proc shape-circles {can coord color size tag} {
		set r [expr {5.0*$size}]
		set ids {}
		foreach {x y} $coord {
			lappend ids [$can create oval \
				[expr {$x-$r}] [expr {$y-$r}] \
				[expr {$x+$r}] [expr {$y+$r}] \
				-outline $color -fill "" -tag $tag]
		}
		return $ids
	}
	
	proc shape-filled-circles {can coord color size tag} {
		set r [expr {5.0*$size}]
		set ids {}
		foreach {x y} $coord {
			lappend ids [$can create oval \
				[expr {$x-$r}] [expr {$y-$r}] \
				[expr {$x+$r}] [expr {$y+$r}] \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}

	proc shape-squares {can coord color size tag} {
		set s [expr {5.0*$size}]
		set ids {}
		foreach {x y} $coord {
		lappend ids [$can create rectangle  \
				[expr {$x-$s}] [expr {$y-$s}] [expr {$x+$s}] [expr {$y+$s}] \
				-outline $color -fill "" -tag $tag]
		}
		return $ids
	}
	
	proc shape-filled-squares {can coord color size tag} {
		set s [expr {5.0*$size}]
		set ids {}
		foreach {x y} $coord {
		lappend ids [$can create rectangle  \
				[expr {$x-$s}] [expr {$y-$s}] [expr {$x+$s}] [expr {$y+$s}] \
				-outline "" -fill $color -tag $tag]
		}
		return $ids
	}


	proc shape-hexagons {can coord color size tag} {
		set s [expr {5.0*$size}]
		set clist {1 -0.5 0 -1.12 -1 -0.5 -1 0.5 0 1.12 1 0.5}
		set ids {}
		foreach {x y} $coord {
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline $color -fill "" -tag $tag]
		}
		return $ids
	}
	
	proc shape-filled-hexagons {can coord color size tag} {
		set s [expr {5.0*$size}]
		set clist {1 -0.5 0 -1.12 -1 -0.5 -1 0.5 0 1.12 1 0.5}
		set ids {}
		foreach {x y} $coord {
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

	proc shape-triangles {can coord color size tag} {
		set s [expr {8.0*$size}]
		set clist {0.0 +1.0 0.5 -0.5 -0.5 -0.5}
		set ids {}
		foreach {x y} $coord {
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline $color -fill "" -tag $tag]
		}
		return $ids
	}
	
	proc shape-filled-triangles {can coord color size tag} {
		set s [expr {8.0*$size}]
		set clist {0.0 +1.0 0.5 -0.5 -0.5 -0.5}
		set ids {}
		foreach {x y} $coord {
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

	proc shape-uptriangles {can coord color size tag} {
		set s [expr {8.0*$size}]
		set clist {0.0 -1.0 0.5 0.5 -0.5 0.5}
		set ids {}
		foreach {x y} $coord {
			set hc {}
			foreach {xc yc} $clist {
				lappend hc [expr {$xc*$s+$x}]
				lappend hc [expr {$yc*$s+$y}]
			}
			lappend ids [$can create polygon $hc \
				-outline $color -fill "" -tag $tag]
		}
		return $ids
	}
	
	proc shape-filled-uptriangles {can coord color size tag} {
		set s [expr {8.0*$size}]
		set clist {0.0 -1.0 0.5 0.5 -0.5 0.5}
		set ids {}
		foreach {x y} $coord {
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
		option -logx -default 0 -configuremethod opset
		option -logy -default 0 -configuremethod opset
		option -grid -default false -configuremethod opset
		option -xtics -default auto -configuremethod opset
		option -ytics -default auto -configuremethod opset
		option -xlabel -default {} -configuremethod opset
		option -ylabel -default {} -configuremethod opset
		option -xformat -default %g -configuremethod opset
		option -yformat -default %g -configuremethod opset
		option -font -default {} -configuremethod fontset
		option -ticlength -default 5
		option -samplelength -default 20
		option -samplesize -default 1.0
		option -key -default {top right}

		option -enhanced -default false -configuremethod unimplemented
		option -redraw -default 0 -readonly yes

		# backing store for plot data
		variable plotdata {}
		variable datasetnr 0
		variable zstack {}

		# computed list of tics and displayrange
		variable xticlist
		variable yticlist
		variable displayrange
		variable displaysize
		
		# store the history of ranges 
		# by zooming with the mouse
		variable zoomstack {}

		# state during mouse action (dragging or clicking)
		variable dragdata {dragging false clicking false}
		
		variable transform

		variable axisfont default

		# store for the interactive elements (=controls)
		variable controls {}

		constructor {args} {
			installhull using canvas
			$self configurelist $args
			bind $win <Configure> [mymethod RedrawRequest]
			
			# bindings for dragging & clicking
			bind $win <ButtonPress-1> [mymethod drag start %x %y]
			bind $win <Button1-Motion> [mymethod drag move %x %y]
			bind $win <ButtonRelease-1> [mymethod drag end %x %y]
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

			parsearg {using u} {} 
			parsearg {with w} points
			parsearg {color lc} auto
			parsearg {pointtype pt} circles
			parsearg {pointsize ps} 1.0
			parsearg {linewidth lw} 1.0
			parsearg {dash} ""
			parsearg {title t} ""
		
			#puts "Plot config: $using $with $color $pointtype $pointsize $linewidth"
			if {$using != {}} {
				set data [transformdata_using $data $using]
			}

			if {$color == "auto"} {
				set colors {red green blue black}
				set ncolors [llength $color]
				set color [lindex $colors [expr {$datasetnr%$ncolors}]]
			}
			
			set datarange [calcdatarange $data]

			set id $datasetnr
			switch $with {
				p -
				points {
					dict set plotdata $id type points 1
					dict set plotdata $id data $data
					dict set plotdata $id datarange $datarange
					dict set plotdata $id color $color
					dict set plotdata $id pointtype $pointtype
					dict set plotdata $id pointsize $pointsize
					dict set plotdata $id title $title
				}
				l -
				lines {
					dict set plotdata $id type lines 1
					dict set plotdata $id data $data
					dict set plotdata $id datarange $datarange
					dict set plotdata $id color $color
					dict set plotdata $id linewidth $linewidth
					dict set plotdata $id dash $dash
					dict set plotdata $id title $title
				}

				lp -
				linespoints {
					dict set plotdata $id type points 1
					dict set plotdata $id type lines 1
					dict set plotdata $id data $data
					dict set plotdata $id datarange $datarange
					dict set plotdata $id color $color
					dict set plotdata $id pointtype $pointtype
					dict set plotdata $id pointsize $pointsize
					dict set plotdata $id title $title
					#
					dict set plotdata $id linewidth $linewidth
					dict set plotdata $id dash $dash
				}

				default {
					return -code error "with must be: points, lines or linespoints"
				}
			}
			
			lappend zstack $id
			$self RedrawRequest
			incr datasetnr
			return $id
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

		method {set auto x} {} {
			$self set xrange *:*
		}

		method {set auto y} {} {
			$self set yrange *:*
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
					# try to parse as float
					if {isfinite($val) && $val > 0} {
						return [list every $val]
					} else {
						return -code error -level 2 "Tics must be float or \"auto\" or \"off\""
					}
				}
			}

			if {[llength $arglist]%2==1} {
				return -code error -level 2 "Tic list must be label pos ?label pos ...?"
			}
			
			# check for float value at every odd pos
			foreach {text pos} $arglist {
				if {!isfinite($pos)} {
					return -code error -level 2 "All tics must be at finite position: \"$text\", $pos"
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

		method getdata {id args} {
			if {[dict exists $plotdata $id]} {
				return [dict get $plotdata $id {*}$args]
			}
		}

		method calcranges {} {
			# compute ranges spanned by data
			set datarange {}
			dict for {id data} $plotdata {
				set datarange [combine_range $datarange [dict get $data datarange]]
			}
			
			set dxmin [lindex [dict get $datarange xmin] $options(-logx) $options(-logy)]
			set dxmax [lindex [dict get $datarange xmax] $options(-logx) $options(-logy)]
			set dymin [lindex [dict get $datarange ymin] $options(-logx) $options(-logy)]
			set dymax [lindex [dict get $datarange ymax] $options(-logx) $options(-logy)]
			
			# now compute range from request & data
			set xwiden {min false max false}
			set ywiden {min false max false}
			lassign $options(-xrange) xmin xmax
			lassign $options(-yrange) ymin ymax 
			if {$xmin =="*" || ($options(-logx) && !islogfinite($xmin))} {
				set xmin $dxmin
				dict set xwiden min true
			}
			if {$ymin =="*" || ($options(-logy) && !islogfinite($ymin))} {
				set ymin $dymin
				dict set ywiden min true
			}
			if {$xmax =="*" || ($options(-logx) && !islogfinite($xmax))} {
				set xmax $dxmax
				dict set xwiden max true
			}
			if {$ymax =="*" || ($options(-logy) && !islogfinite($ymax))} {
				set ymax $dymax
				dict set ywiden max true
			}

			# now, we could still have an unusable range in case the data
			# doesn't provide us with a sensible range; then fake it

			if {$xmin > $xmax} {
				# not a single valid point
				lassign {1.0 2.0} xmin xmax
			}

			if {$xmin == $xmax} {
				# only one value
				if {$options(-logx)} {
					set xm $xmin
					set xmin [expr {$xm*0.999}]
					set xmax [expr {$xm*1.001}]
				} else {
					set xm $xmin
					set xmin [expr {$xm-0.001}]
					set xmax [expr {$xm+0.001}]
				}
			}
		
			if {$ymin > $ymax} {
				# not a single valid point
				lassign {1.0 2.0} ymin ymax
			}

			if {$ymin == $ymax} {
				# only one value
				if {$options(-logx)} {
					set ym $ymin
					set ymin [expr {$ym*0.999}]
					set ymax [expr {$ym*1.001}]
				} else {
					set ym $ymin
					set ymin [expr {$ym-0.001}]
					set ymax [expr {$ym+0.001}]
				}
			}

			# now we have the tight range in xmin,xmax, ymin, ymax
			# compute ticlists and round for data determined values
			lassign [compute_ticlist $xmin $xmax $options(-xtics) \
				$options(-logx) $xwiden $options(-xformat)] xticlist xmin xmax
			
			lassign [compute_ticlist $ymin $ymax $options(-ytics) \
				$options(-logy) $ywiden $options(-yformat)] yticlist ymin ymax

			set displayrange [dict create xmin $xmin xmax $xmax ymin $ymin ymax $ymax]
			
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

			set dxmin [dict get $displaysize xmin]
			set dxmax [dict get $displaysize xmax]
			set dymin [dict get $displaysize ymin]
			set dymax [dict get $displaysize ymax]

			if {$options(-logx)} {
				set xmin [expr {log($xmin)}]
				set xmax [expr {log($xmax)}]
			}
			
			lassign [compute_rangetransform \
					$xmin $xmax $dxmin $dxmax] xmul xadd
			
			if {$options(-logy)} {
				set ymin [expr {log($ymin)}]
				set ymax [expr {log($ymax)}]
			}
			
			lassign [compute_rangetransform \
					$ymin $ymax $dymin $dymax] ymul yadd
			
			set transform [list $xmul $xadd $ymul $yadd]
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
			}
		}

		method drawpoints {id} {
			set data [dict get $plotdata $id data]
			lassign [geometry::pointclip $data $displayrange] clipdata clipinfo
			# store away the clipped & transformed data
			# together with the info of the clipping
			# needed for picking points
			dict set plotdata $id clipinfo $clipinfo
			set transdata [$self graph2pix $clipdata]
			dict set plotdata $id transdata $transdata

			set shapeproc shape-[dict get $plotdata $id pointtype]
			$shapeproc $hull $transdata \
				[dict get $plotdata $id color] \
				[dict get $plotdata $id pointsize]	\
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
				if {!isfinite($x) || !isfinite($y)} { 
					# NaN value, start a new piece
					if {[llength $piece]>0} { 
						lappend pieces $piece
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
	
		method drawlegend {} {
			# draw the titles and a sample
			set lineheight [font metrics $axisfont -linespace]
			# create list of all ids that have titles
			# in correct zstack order
			foreach id $zstack {
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
			$hull delete $selfns
			# puts "Now drawing [$self configure]"
			if {[dict size $plotdata] == 0} { return }
			$self calcranges
			$self calcsize
			$self calctransform
			$self drawcoordsys
			$self drawdata
			$self drawlegend
			incr options(-redraw)
			# notify embedded controls
			set errors {}
			foreach c $controls {
				if {[catch {$c Configure $displaysize} err]} {
					lappend errors $err
				}
			}
			if {[llength $errors] > 0} {
				# rethrow errors
				return -code error [join $errors \n]

			}
		}
		
		method clear {} {
			$hull delete $selfns
			set plotdata {}
			set zstack {}
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

		method {drag end} {x y} {
			# user has released mouse button
			# check if it was a click or a drag (zoom)
			if {[dict get $dragdata clicking]} {
				# inverse transform this point
				set xgraph [$self pixToX $x]
				set ygraph [$self pixToY $y]
				event generate $win <<Click>> -x $x -y $y -data [list $xgraph $ygraph]
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
			event generate $win <<MotionEvent>> -data [list $xgraph $ygraph]
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
			set size [list [winfo width $hull] [winfo height $hull]]
			set pdf [pdf4tcl::new %AUTO% -paper $size -compress false]
			$pdf canvas $hull
			$pdf write -file $fn
			$pdf destroy
		}

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
			}
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
	}

	proc ::tcl::mathfunc::isfinite {x} {
		# determine, whether x,y is a valid point
		expr {[string is double -strict $x] && $x < Inf && $x > -Inf}
	}
		
	proc ::tcl::mathfunc::islogfinite {x} {
		# determine, whether x,y is a valid point on the logscale
		expr {[string is double -strict $x] && $x < Inf && $x > 0}
	}

}
