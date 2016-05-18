# Python script for testing the ruediPy code
# 
#
# Copyright 2016, Matthias Brennwald (brennmat@gmail.com) and Yama Tomonaga
# 
# This file is part of ruediPy, a toolbox for operation of RUEDI mass spectrometer systems.
# 
# ruediPy is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ruediPy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with ruediPy.  If not, see <http://www.gnu.org/licenses/>.
# 
# ruediPy: toolbox for operation of RUEDI mass spectrometer systems
# Copyright (C) 2016  Matthias Brennwald
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# make shure Python knows where to look for the RUEDI Python code
# http://stackoverflow.com/questions/4580101/python-add-pythonpath-during-command-line-module-run
# Example (bash): export PYTHONPATH=~/ruedi/python

# import general purpose Python classes:
import time
from datetime import datetime
import os
havedisplay = "DISPLAY" in os.environ
if havedisplay: # prepare plotting environment
	import matplotlib
	matplotlib.use('GTKAgg') # use this for faster plotting
	import matplotlib.pyplot as plt

# import ruediPy classes:
from classes.rgams_SRS		import rgams_SRS
from classes.selectorvalve_VICI	import selectorvalve_VICI
from classes.datafile		import datafile

# set up ruediPy objects:
MS        = rgams_SRS ( serialport = '/dev/serial/by-id/pci-WuT_USB_Cable_2_WT2304837-if00-port0' , label = 'MS_MINIRUEDI_TEST', max_buffer_points = 1000 )
VALVE     = selectorvalve_VICI ( serialport = '/dev/serial/by-id/pci-WuT_USB_Cable_2_WT2350938-if00-port0', label = 'INLETSELECTOR' )
DATAFILE  = datafile ( '~/ruedi_data' )

# start data file:
DATAFILE.next() # start a new data file
print 'Data output to ' + DATAFILE.name()

# change valve positions:
VALVE.setpos(1,DATAFILE)
print 'Valve position is ' + str(VALVE.getpos())
VALVE.setpos(2,DATAFILE)
print 'Valve position is ' + str(VALVE.getpos())
VALVE.setpos(3,DATAFILE)
print 'Valve position is ' + str(VALVE.getpos())

# print some MS information:
print 'MS has electron multiplier: ' + MS.hasMultiplier()
print 'MS max m/z range: ' + MS.mzMax()

# change MS configuraton:
#MS.setElectronEnergy(60)
#print 'Ionizer electron energy: ' + MS.getElectronEnergy() + ' eV'
MS.setDetector('F')
print 'Set ion beam to Faraday detector: ' + MS.getDetector()
MS.filamentOn() # turn on with default current
print 'Filament current: ' + MS.getFilamentCurrent() + ' mA'

# scan Ar-40 peak:
print 'Preparing scan (waiting for air inflow)... '
VALVE.setpos(3,DATAFILE)
time.sleep(10)
print 'Scanning...'
MS.setGateTime(0.3) # set gate time for each reading
mz,intens,unit = MS.scan(38,42,15,0.5,DATAFILE)
MS.plot_scan (mz,intens,unit)
print '...done.'

# series of sinlge mass measurements ('PEAK' readings):
print 'Single mass measurements...'
gate = 0.025
mz = (28, 32, 40, 44)
j = 0
while j < 100000:
	pos = j%4 + 1 # valve position
	VALVE.setpos(pos,DATAFILE) # set inlet valve position
	print 'Valve position is ' + str(VALVE.getpos())
	if pos == 4: # standard / air calibration
		DATAFILE.next('C') # start a new data file, typ 'C' (calibration)
	else: # sample	
		DATAFILE.next('S') # start a new data file, typ 'S' (sample)

	k = 0
	while k < 100: # single peak readings
		k = k+1
		print 'Frame ' + str(k) + ':'
		for m in mz:
			peak,unit = MS.peak(m,gate,DATAFILE) # get PEAK value
			print '  mz=' + str(m) + ' peak=' + str(peak) + ' ' + unit # show PEAK value on console

		if k%5 == 0: # update trend plot every 5th iteration
			MS.plot_peakbuffer() # plot PEAK values in buffer (time trend)
		
	j = j+1
		
print '...done.'

# turn off filament:
MS.filamentOff()
print 'Filament current: ' + MS.getFilamentCurrent() + ' mA'

print '...done.'

# Wait to exit:
input("Press ENTER to exit...")
