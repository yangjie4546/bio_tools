#! /usr/bin/env perl
use strict;
use warnings;

my $result_dir="01.output";
my $length_file="effective.len";
my $miu=1.26e-8;
my $gen_time=6;
my $out_file="$0.sta";
my $fs="dadi.fs";

my @files=<$result_dir/*>;

my %hash;
foreach my $file(@files){
    open(I,"< $file");
    while(<I>){
        chomp;
        next unless(/DADIOUTPUT/);
        my $param_name=<I>;
        my $param_value=<I>;
        chomp $param_name;
        chomp $param_value;
        next if($param_value=~/--/ || $param_value=~/nan/);
        my @params=split(/\s+/,$param_value);
        $hash{$file}{likelihood}=$params[0];
        $hash{$file}{param_value}=$param_value;
        $hash{$file}{param_name}=$param_name;
    }
    close I;
}

open(I,"< $length_file");
my $length=<I>;
chomp $length;
print "$length\n";
close I;

open S,">> $out_file";
print S "### new result ###\n";
my $time=`date`;
chomp $time;
print S "$time\n";
foreach my $file(sort {$hash{$b}{likelihood} <=> $hash{$a}{likelihood}} keys %hash){
    my $param_name=$hash{$file}{param_name};
    my $param_value=$hash{$file}{param_value};
    my @names=split(/\s+/,$param_name);
    my @params=split(/\s+/,$param_value);
    &plot(@params);
    print "$file\n";
    print S "$file\n";
    print "$param_name\n$param_value\n";
    print S "$param_name\n$param_value\n";
    my $theta=$params[1]/$length;
    print "theta:\t$theta\n";
    print S "theta:\t$theta\n";
    my $nref=$theta/(4*$miu);
    print "Nref:\t$nref\n";
    print S "Nref:\t$nref\n";
    for(my $i=2;$i<@names;$i++){
        $names[$i]=~/^(\w)\./;
        my $type=$1;
        # print "$type\n";
        my $param=$params[$i];
        if($type eq "N"){
            $param = $param * $nref;
        }
        elsif($type eq "T"){
            $param = 2 * $nref * $param * $gen_time;
        }
        elsif($type eq "M"){
            # $param = 2 * $nref * $param;
            $param = $param / (2 * $nref);
        }
        print "$type\t$names[$i]\t$param\n";
        print S "$type\t$names[$i]\t$param\n";
    }
    last;
}
close S;

sub plot{
    my @params=@_;
    shift @params;
    shift @params;
    my $params=join ",",@params;
    open(O,"> 04.plot.py");
    print O "
#! /usr/bin/env python2
import matplotlib
matplotlib.use('Agg')
import numpy
import sys
from numpy import array
import pylab
import dadi

data = dadi.Spectrum.from_file(\"$fs\")
data = data.fold()
ns = data.sample_sizes
pts_l = [40,50,60]
func = dadi.Demographics2D.IM_pre

p0 = [ $params ]
func_ex = dadi.Numerics.make_extrap_log_func(func)
model = func_ex(p0, ns, pts_l)

pylab.figure()
dadi.Plotting.plot_2d_comp_multinom(model, data, vmin=1, resid_range=50,pop_ids =('pda','pro'))
pylab.show()
pylab.savefig('model_10.pdf', format='pdf')

";
    close O;
}