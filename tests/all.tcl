package require tcltest 2.2
namespace import ::tcltest::*

configure -testdir [file dirname [file normalize [info script]]] {*}$argv
set failed [runAllTests]
# runAllTests returns 1 on failures in tcltest >= 2.5; older versions return "".
exit [expr {$failed eq "1"}]
