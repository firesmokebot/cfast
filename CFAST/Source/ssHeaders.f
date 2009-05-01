      subroutine ssHeadersNormal
      
      ! This is the header information for the normal spreadsheet output
      
      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "cshell.fi"
      include "objects1.fi"
      
      ! local variables     
      parameter (maxhead = 1+7*nr+5+7*mxfire)
      character*35 headertext(3,maxhead), cTemp,
     *  Labels(15), LabelsShort(15), LabelUnits(15)
     *  
     
      data Labels / 'Time', 
     *              'Upper Layer Temperature', 
     *              'Lower Layer Temperature',
     *              'Layer Height',
     *              'Upper Layer Volume',
     *              'Pressure',
     *              'Ambient Temp Target Flux',
     *              'Floor Temp Target Flux',
     *              'Plume Entrainment Rate',
     *              'Pyrolysis Rate',
     *              'HRR',
     *              'Flame Height',
     *              'Convective HRR',
     *              'Total Pyrolysate Released',
     *              'Total Trace Species Released' /
      data LabelsShort / 'Time', 'ULT_', 'LLT_', 'HGT_', 'VOL_',
     *                   'PRS_', 'ATARG_', 'FTARG_', 'PLUM_', 
     *                   'PYROL_', 'HRR_', 'FHGT_', 'HRR_C_',
     *                   'PYROL_T_', 'TRACE_T_' /
      data LabelUnits / 's', 'C', 'C', 'm', 'm^3', 'Pa', 'W/m^2', 
     *                  'W/m^2', 'kg/s', 'kg/s', 'W', 'm', 'W',
     *                  'kg', 'kg' /

      !  spreadsheet header
      if (validation) then
        headertext(1,1) = LabelsShort(1)
        headertext(2,1) = LabelUnits(1)
        headertext(3,1) = ' '
      else
        headertext(1,1) = Labels(1)
        headertext(2,1) = ' '
        headertext(3,1) = LabelUnits(1)
      end if
      position = 1
        
      ! Compartment variables
      do j = 1, nm1
        do i = 1, 7
          if (i.ne.2.or.izshaft(j).eq.0) then
            if (i.ne.3.or.izshaft(j).eq.0) then
              position = position + 1
              if (validation) then
                if (j.lt.10) then
                  write (cTemp,'(a,i1)') trim(LabelsShort(i+1)), j
                else
                  write (cTemp,'(a,i2)') trim(LabelsShort(i+1)), j
                end if
                headertext(1,position) = cTemp
                headertext(2,position) = LabelUnits(i+1)
                headertext(3,1) = ' '
              else
                headertext(1,position) = Labels(i+1)
                headertext(2,position) = compartmentnames(j)
                headertext(3,position) = LabelUnits(i+1)
              end if
            end if
          end if
        end do
      end do
        
      ! Fire variables. Main fire first, then object fires
      if (lfbo.gt.0) then
        do i = 1, 7
          position = position + 1
          if (validation) then
            write (cTemp,'(a,i1)') trim(LabelsShort(i+8)), 0
            headertext(1,position) = cTemp
            headertext(2,position) = LabelUnits(i+8)
            headertext(3,1) = ' '
          else
            headertext(1,position) = Labels(i+8)
            headertext(2,position) = 'Mainfire'
            headertext(3,position) = LabelUnits(i+8)
          end if  
        end do
      endif
        do j = 1, numobjl
        do i = 1, 7
          position = position + 1
          if (validation) then
            if (j.lt.10) then
              write (cTemp,'(a,i1)') trim(LabelsShort(i+8)), j
            else
              write (cTemp,'(a,i2)') trim(LabelsShort(i+8)), j
            end if
            headertext(1,position) = cTemp
            headertext(2,position) = LabelUnits(i+8)
            headertext(3,1) = ' '
          else
            headertext(1,position) = Labels(i+8)
            headertext(2,position) = objnin(j)
            headertext(3,position) = LabelUnits(i+8)
          end if
        end do
      end do
        
      ! write out header
      write(15,"(1024(a,','))") (trim(headertext(1,i)),i=1,position)
      write(15,"(1024(a,','))") (trim(headertext(2,i)),i=1,position)
      write(15,"(1024(a,','))") (trim(headertext(3,i)),i=1,position)
      
      end subroutine ssHeadersNormal
      
      subroutine ssHeadersSpecies
      
      ! This is the header information for the spreadsheet output
      
      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "cshell.fi"
      
      ! local variables     
      parameter (maxhead = 1+7*nr+5+7*mxfire)
      character*35 headertext(3,maxhead), cTemp,
     *  Labels(23), LabelsShort(23), LabelUnits(23)
      logical tooutput(11)/.false.,5*.true.,.false.,4*.true./
      integer position
     
      data Labels / 'Time', 
     *              'N2 Upper Layer',
     *              'O2 Upper Layer', 
     *              'CO2 Upper Layer',
     *              'CO Upper Layer',
     *              'HCN Upper Layer',
     *              'HCL Upper Layer',
     *              'Unburned Hydrocarbons Upper Layer',
     *              'H2O Upper Layer',
     *              'Optical Density Upper Layer',
     *              'C-T Product Upper Layer',
     *              'Trace Species Upper Layer', 
     *              'N2 Lower Layer',
     *              'O2 Lower Layer', 
     *              'CO2 Lower Layer',
     *              'CO Lower Layer',
     *              'HCN Lower Layer',
     *              'HCL Lower Layer',
     *              'Unburned Hydrocarbons Lower Layer',
     *              'H2O Lower Layer',
     *              'Optical Density Lower Layer',
     *              'C-T Product Lower Layer',
     *              'Trace Species Lower Layer' / 
      data LabelsShort / 'Time', 'ULN2', 'ULO2_', 'ULCO2_', 'ULCO_', 
     *                   'ULHCN_', 'ULHCL_', 'ULTUHC_', 'ULH2O_', 
     *                   'ULOD_', 'ULCT_', 'ULTS_', 'LLN2', 'LLO2_', 
     *                   'LLCO2_', 'LLCO_', 'LLHCN_', 'LLHCL_', 
     *                   'LLTUHC_', 'LLH2O_', 'LLOD_', 'LLCT_', 'LLTS_'/
      data LabelUnits / 's', 'mol %', 'mol %', 'mol %', 'PPM', 'PPM',
     *                  'PPM', 'mol %', 'mol %', '1/m', 'g-min/m^3', 
     *                  'kg', 'mol %', 'mol %', 'mol %', 'PPM', 'PPM', 
     *                  'PPM', 'mol %', 'mol %', '1/m', 'g-min/m^3', 
     *                  'kg' /

      !  spreadsheet header
      if (validation) then
        headertext(1,1) = LabelsShort(1)
        headertext(2,1) = LabelUnits(1)
        headertext(3,1) = ' '
      else
        headertext(1,1) = Labels(1)
        headertext(2,1) = ' '
        headertext(3,1) = LabelUnits(1)
      end if
      position = 1
      
      ! Species by compartment, then layer, then species type
      do i = 1, nm1
        do j = upper, lower
          if (j.eq.upper.or.izshaft(j).EQ.0) then
            do lsp = 1, NS
              if(tooutput(lsp)) then
                position = position + 1
                if (validation) then
                  if (j.lt.10) then
                    write (cTemp,'(a,i1)') 
     *                     trim(LabelsShort((j-1)*11+lsp+1)), i
                  else
                    write (cTemp,'(a,i2)')  
     *                     trim(LabelsShort((j-1)*11+lsp+1)), i
                  end if
                  headertext(1,position) = cTemp
                  headertext(2,position) = LabelUnits((j-1)*11+lsp+1)
                  headertext(3,1) = ' '
                else
                  headertext(1,position) = Labels((j-1)*11+lsp+1)
                  headertext(2,position) = compartmentnames(i)
                  headertext(3,position) = LabelUnits((j-1)*11+lsp+1)
                end if
              end if
            end do
          end if
         end do
      end do
            
      ! write out header
      write(17,"(1024(a,','))") (trim(headertext(1,i)),i=1,position)
      write(17,"(1024(a,','))") (trim(headertext(2,i)),i=1,position)
      write(17,"(1024(a,','))") (trim(headertext(3,i)),i=1,position)
      
      end subroutine ssHeadersSpecies
      
      subroutine ssHeadersFlux

! This routine spools the headers for the surface temperature and flux results.

! Format

!blank     c1     c1      c1    c1      c1   c1    c1      c1   c1         c2     c2      c2    c2       c2   c2   c2     c2   c2       ....
!time   ceiling	u-wall  l-wall floor  flux  fire surface gas convect   ceiling u-wall  l-wall floor  flux  fire surface gas convect    ....
       

!.....  target number
!.....  gas temp, surface temp, center temp, flux, fire, surface, gas, convect


!.....  sensor number
!.....  compartment name, type, sensor temperature, activated, smoke temperature, smoke velocity


      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "cshell.fi"
      include "fltarget.fi"
      
      ! local variables     
      parameter (maxhead = 1+9*nr+8*mxtarg+4*mxdtect)
      character*35 headertext(3,maxhead), cTemp, cType,
     *  Labels(22), LabelsShort(22), LabelUnits(22)
      integer position 
     
      data Labels / 'Time', 
     *              'Ceiling Temperature',
     *              'Upper Wall Temperature',
     *              'Lower Wall Temperature', 
     *              'Floor Temperature',
     *              'Floor Target Total Flux',
     *              'Floor Target Fire Radiative Flux',
     *              'Floor Target Surface Radiative Flux',
     *              'Floor Target Gas Radiative Flux',
     *              'Floor Target Convective Flux',
     *              'Target Surrounding Gas Temperature',
     *              'Target Surface Temperature',
     *              'Target Center Temperature',
     *              'Target Total Flux',
     *              'Target Fire Radiative Flux',
     *              'Target Surface Radiative Flux',
     *              'Target Gas Radiative Flux',
     *              'Target Convective Flux',
     *              'Sensor Temperature',
     *              'Sensor Activation',
     *              'Sensor Surrounding Gas Temperature',
     *              'Sensor Surrounding Gas Velocity' /
     
      data LabelsShort /'Time', 'CEILT_', 'UWALLT_', 'LWALLT_', 
     *                  'FLOORT_', 'FFLUXT_', 'FFLUXF_',
     *                  'FFLUXS_', 'FFLUXG_', 'FFLUXC_',
     *                  'TARGGAST_', 'TARGSURT_', 'TARGCENT_',
     *                  'TARGFLUXT_', 'TARGFLUXF_', 'TARGFLUXS_',
     *                  'TARGFLUXG_', 'TARGFLUXC_', 'SENST_',
     *                  'SENSACT_', 'SENSGAST_', 'SENSGASVEL_' /
     
      data LabelUnits / 's', 4*'C', 5*'W', 3*'C', 5*'W', 'C', '1=yes',
     *                  'C', 'm/s' /

      !  spreadsheet header
      if (validation) then
        headertext(1,1) = LabelsShort(1)
        headertext(2,1) = LabelUnits(1)
        headertext(3,1) = ' '
      else
        headertext(1,1) = Labels(1)
        headertext(2,1) = ' '
        headertext(3,1) = LabelUnits(1)
      end if
      position = 1

      ! Compartment surfaces and the floor target
      do i = 1, nm1
	  do j = 1, 9
	    position = position + 1
	    if (validation) then
	      if (i.lt.10) then
               write (cTemp,'(a,i1)') trim(LabelsShort(j+1)), i
            else
               write (cTemp,'(a,i2)') trim(LabelsShort(j+1)), i
            end if
            headertext(1,position) = cTemp
            headertext(2,position) = LabelUnits(j+1)
            headertext(3,position) = ' '
	    else
	      headertext(1,position) = Labels(j+1)
	      headertext(2,position) = compartmentnames(i)
	      headertext(3,position) = LabelUnits(j+1)
	    end if
	  end do
	end do

!	All the additional targets

      do i = 1, nm1
        IF (NTARG.GT.NM1) then
          DO ITARG = 1, NTARG-NM1
            if (IXTARG(TRGROOM,ITARG).EQ.I) then
			  do j = 1, 8
			    position = position + 1
			    if (validation) then
	            if (itarg.lt.10) then
                    write (cTemp,'(a,i1)') trim(LabelsShort(j+10)),itarg
                  else
                    write (cTemp,'(a,i2)') trim(LabelsShort(j+10)),itarg
                  end if
                  headertext(1,position) = cTemp
                  headertext(2,position) = LabelUnits(j+10)
                  headertext(3,position) = ' '
	          else
	            headertext(1,position) = Labels(j+10)
	            write (cTemp,'(a,i2)') 'Target ',itarg
	            headertext(2,position) = cTemp
	            headertext(3,position) = LabelUnits(j+10)
	          end if
			  end do  
            end if
   30     end do
        end if
      end do

!	Hall flow needs to go here

!	Detectors

	do i = 1, ndtect
        itype = ixdtect(i,dtype)
		write(tnum,"(i2)") i
		if (itype.eq.smoked) then
		  cType = 'Smoke'
		elseif (itype.eq.heatd) then
	 	  cType = 'Heat'
	  else
	    cType = 'Other'
		endif
	  do j = 1, 4
	    position = position + 1
	    if (validation) then
	    else
	      headertext(1,position) = Labels(j+18)
	      write (cTemp,'(a,1x,a,1x,i2)') trim(cType), 'Sensor', i
	      headertext(2,position) = cTemp
	      headertext(3,position) = LabelUnits(j+18)
	    end if
        end do
      end do
            
      ! write out header
      write(18,"(1024(a,','))") (trim(headertext(1,i)),i=1,position)
      write(18,"(1024(a,','))") (trim(headertext(2,i)),i=1,position)
      write(18,"(1024(a,','))") (trim(headertext(3,i)),i=1,position)
      
      return
      end subroutine ssHeadersFlux
      
      SUBROUTINE ssHeadersFlow

!	This is the header information for the flow spreadsheet and is called once
!	The logic is identical to SpreadSheetFlow so the output should be parallel

      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "cshell.fi"
      include "vents.fi"

      ! local variables     
      parameter (maxhead = mxvents+2*mxvv+2*mxhvsys+mfan)
      character*35 headertext(3,maxhead), cTemp, cFrom, cTo,
     *  Labels(11), LabelsShort(11), LabelUnits(11)
      integer position  
     
      data Labels / 'Time', 
     *              'HVENT Inflow',
     *              'HVENT Outflow',
     *              'HVENT Mixing to Upper Layer', 
     *              'HVENT Mixing to Lower Layer',
     *              'VVENT Inflow',
     *              'VVENT Outflow',
     *              'MVENT Inflow',
     *              'MVENT Outflow',
     *              'MVENT Trace Species Flow',
     *              'MVENT Trace Species Filtered' /
     
      data LabelsShort /'Time', 'H_IN_', 'H_OUT_', 'H_MIXUP_', 
     *                  'H_MIXLOW_', 'V_IN_', 'V_OUT_', 'MV_IN_',
     *                  'MV_OUT_', 'MV_TRACE_', 'MV_FILTERED_' /
     
      data LabelUnits / 9*'kg/s', 2*'kg' /

      !  spreadsheet header
      if (validation) then
        headertext(1,1) = LabelsShort(1)
        headertext(2,1) = LabelUnits(1)
        headertext(3,1) = ' '
      else
        headertext(1,1) = Labels(1)
        headertext(2,1) = ' '
        headertext(3,1) = LabelUnits(1)
      end if
      position = 1

      !	Do the output by compartments

      do irm = 1, n
        i = irm

C     Natural flow through vertical vents (horizontal flow)

        do j = 1, n
          do k = 1, mxccv
            if (iand(1,ishft(nw(i,j),-k)).ne.0) then
              iijk = ijk(i,j,k)
              if (j.eq.n) then
                cFrom = 'Outside'
              else
                if (j.lt.10) then
                  write (cFrom,'(i1)') j
                else
                  write (cFrom,'(i2)') j
                end if
              end if
              if (validation) then
              else
                do ih = 1, 4
                  if (j.ne.n.or.ih.lt.3) then
                    position = position + 1
                    headertext(1,position) = Labels(ih+1)
                    write (ctemp,'(a,i2,1x,2a,i2)') 
     *                    'Vent #',k,trim(cFrom),'-',i
                    headertext(2,position) = ctemp
                    headertext(3,position) = LabelUnits(ih+1)
                  end if
                end do
              end if
            end if
          end do
        end do

!	Natural flow through horizontal vents (vertical flow)

        do j = 1, n
          if (nwv(i,j).ne.0.or.nwv(j,i).ne.0) then
            if (i.lt.10) then
              write (cFrom,'(i1)') i
            else
              write (cFrom,'(i2)') i
            end if
            if (i.eq.n) cFrom = 'Outside'
            if (j.lt.10) then
              write (cTo,'(i1)') j
            else
              write (cTo,'(i2)') j
            end if
			if (j.eq.n) cTo = 'Outside'
		    if (validation) then
		    else
		      do ih = 1,2
		        position = position + 1
		        headertext(1,position) = Labels(ih+5)
		        write (ctemp,'(a,1x,3a)') 
     *                'Vent #',trim(cFrom),'-',trim(cTo)
		        headertext(2,position) = cTemp
		        headertext(3,position) = LabelUnits(ih+5)
		      end do
		    end if 
          end if
        end do

!	Mechanical ventilation

        if (nnode.ne.0.and.next.ne.0) then
          do i = 1, next
            ii = hvnode(1,i)
            if (ii.eq.irm) then
              inode = hvnode(2,i)
	        write (cFrom,'(i2)') ii
              if (ii.eq.n) cnum = 'Outside'
              write (cTo,'(i2)') inode
              do ih = 1,4
                position = position + 1
                if (validation) then
                else
                  headertext(1,position) = Labels(ih+7)
                  if (ih.le.2) then
                    headertext(2,position) = 'Vent Connection at Node '
     *                                // trim(cFrom) // '-' // trim(cTo)
                  else
                    headertext(2,position) = 'Fan at Node ' // cTo
                  end if
                  headertext(3,position) = LabelUnits(ih+7)
                end if
              end do
            end if
          end do
        end if
   70 end do
            
      ! write out header
      write(16,"(1024(a,','))") (trim(headertext(1,i)),i=1,position)
      write(16,"(1024(a,','))") (trim(headertext(2,i)),i=1,position)
      write(16,"(1024(a,','))") (trim(headertext(3,i)),i=1,position)

	return

	end subroutine ssHeadersFlow

	subroutine SSFlowAtoH (position, maxoutput, heading, ostring)

	character heading*30(maxoutput), ostring*30
	integer position, length

	if (position.gt.maxoutput) return

	position = position + 1
	heading(position) = trim (ostring) // ','
	return
	
	END

