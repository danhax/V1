
!! CONFIGURATION SUBROUTINES.  SLATER DETERMINANTS NOT SPIN EIGFUNCTS.
!!  SEE WALKS.F90 FOR MORE; SPIN.F90 FOR SPIN PROJECTION.

#include "Definitions.INC"



!! ORBITAL ORDERING:  RETURNS SPINORBITAL INDEX GIVEN ORBITAL INDEX AND SPIN
!! (SPIN IS 1 (ALPHA) OR 2 (BETA))

function iind(twoarr)
  use parameters
  implicit none
  integer :: iind, twoarr(2)
  if (orderflag==1) then
     iind=twoarr(1) + (twoarr(2)-1)*nspf 
  else
     iind=(twoarr(1)-1)*2 + twoarr(2)
  endif
end function


!! RETURN CONFIGURATION INDEX GIVEN ORBITAL OCCUPANCIES

function getconfiguration(thisconfig)
  use parameters
  implicit none
  integer :: getconfiguration, oldgetconfiguration, newgetconfiguration, thisconfig(ndof)

  if (numconfig.gt.10) then 
    getconfiguration=newgetconfiguration(thisconfig)
  else
    getconfiguration=oldgetconfiguration(thisconfig)
  endif
end function getconfiguration

function oldgetconfiguration(thisconfig)
  use parameters
  use configmod
  implicit none
  integer :: oldgetconfiguration, thisconfig(ndof), i, j,flag,k

  i=-1;  j=0;  flag=0
  do while (flag.eq.0)
     j=j+1;     flag=1
     do k=1,ndof
        if (configlist(k,j) /= thisconfig(k)) then
           flag=0;           exit
        endif
     enddo
     if (flag.eq.1) then
        i=j
     endif
     if (j.eq.numconfig) then
        flag=1
     endif
  enddo
  oldgetconfiguration=i
end function oldgetconfiguration



function newgetconfiguration(thisconfig)
  use parameters
  use configmod
  implicit none
  integer :: newgetconfiguration, thisconfig(ndof),  j,flag,k, dir,newdir, step,aa,bb, ii,kk,jj,flag1,flag2
  logical :: allowedconfig

  newgetconfiguration=-1

  if (.not.allowedconfig(thisconfig)) then
    return
  endif

  dir=1;  j=1;  step=numconfig/4;  flag=0

  do while (flag.eq.0)
     flag=1
     do k=1,numelec


!!NEWCONFIGFLAG        if (newconfigflag.ne.0) then
           aa=configlist(2*k-1,j);        bb=thisconfig(2*k-1)
!!NEWCONFIGFLAG        else
!!NEWCONFIGFLAG           aa=iind(configlist(2*k-1:2*k,j));        bb=iind(thisconfig(2*k-1:2*k))
!!NEWCONFIGFLAG        endif

        if (aa .ne. bb) then
           flag=0
           if (aa.lt.bb) then
              newdir=1
           else
              newdir=-1
           endif
           if (newdir.ne.dir) then
              step=max(1,step/2)
           endif
           dir=newdir;           j=j+dir*step
           if (j.le.1) then
              j=1;              dir=1
           endif
           if (j.ge.numconfig) then
              j=numconfig;              dir=-1
           endif
           exit
        endif
     enddo
  enddo


     ii=j

!! DON'T HAVE MAXSPINSETSIZE YET.     do j=max(1,ii-maxspinsetsize),min(numconfig,ii+maxspinsetsize)

     kk=(-1); flag1=0; flag2=0
     do while (flag1.eq.0.or.flag2.eq.0)
        kk=kk+1
        do jj=0,1
           j=ii+kk*(-1)**jj
           if (jj.eq.0.and.j.gt.numconfig) then
              flag1=1
              cycle
           endif
           if (jj.eq.1.and.j.lt.1) then
              flag2=1
              cycle
           endif

           flag=1
           do k=1,ndof
              if (thisconfig(k).ne.configlist(k,j)) then
                 flag=0
                 exit
              endif
           enddo
           if (flag.eq.1) then
              newgetconfiguration=j
              return
           endif
        enddo
     enddo

     call printconfig(thisconfig)
     OFLWR "NEWGETCONFIG NEWCONFIG ERROR"; CFLST

end function newgetconfiguration



!! RETURN CONFIGURATION INDEX GIVEN ORBITAL OCCUPANCIES

!! PUTS AN UN ORDERED CONFIGURATION INTO PROPER (INDEX INCREASING) ORDER
!! AND RETURNS SIGN OF PERMUTATION

function reorder(thisconfig)
  use parameters
  implicit none
  integer :: reorder, thisconfig(1:ndof), phase, flag, jdof, temporb(2), iind

  phase=1;  flag=0
  do while (flag==0)
     flag=1
     do jdof=1,numelec-1
        if (iind(thisconfig((jdof-1)*2+1:jdof*2)) .gt. &
             iind(thisconfig(jdof*2+1:(jdof+1)*2))) then
           phase=phase*(-1)
            flag=0
           temporb = thisconfig((jdof-1)*2+1:jdof*2)
           thisconfig((jdof-1)*2+1:jdof*2) = thisconfig(jdof*2+1:(jdof+1)*2)
           thisconfig(jdof*2+1:(jdof+1)*2) = temporb
        endif
     enddo
  enddo
  reorder=phase
end function


!! INDICATES WHETHER A GIVEN CONFIG IS IN OUR CONFIGURATION LIST

function allowedconfig(thisconfig)
  use parameters
  implicit none

  integer :: thisconfig(ndof), i, isum, j, tempcount, tempcount2, ishell, ii, k, iind, getugval,getmval
  logical :: allowedconfig, tempflag

  do j=1,numelec
     do i=j+1,numelec
        if ( (thisconfig(2*i-1)==thisconfig(2*j-1)).and.(thisconfig(2*i)==thisconfig(2*j)) ) then
           allowedconfig=.false.;           return
        endif
     enddo
  enddo
  do j=1,numelec
     i=thisconfig(j*2-1)
     if ((i.lt.1).or.(i.gt.nspf)) then
        allowedconfig=.false.;        return
     endif
  enddo
  if (restrictflag==1) then    ! by m_s
     isum=0
     do i=2,numelec*2,2
        isum=isum+(thisconfig(i)*2-3)
     enddo
     if (isum /= restrictms) then
        allowedconfig=.false.;        return
     endif
  end if
  if (spfrestrictflag==1) then
     if (mrestrictflag==1.or.mrestrictmin.gt.-99999.or.mrestrictmax.lt.99999) then    ! by m
        isum=getmval(thisconfig)
        if ((mrestrictflag==1.and.isum /= mrestrictval).or.isum.lt.mrestrictmin.or.isum.gt.mrestrictmax) then
           allowedconfig=.false.;        return
        endif
     endif
  end if

  if ((spfugrestrict==1).and.(ugrestrictflag==1)) then    ! by m
     isum=getugval(thisconfig)
     if (isum /= ugrestrictval) then
        allowedconfig=.false.
        return
     endif
  end if

  tempcount=0
  do i=allshelltop(numshells-1)+1,allshelltop(numshells)
     do ii=1,2
        k=iind((/ i,ii /));        tempflag=.false.
        do j=1,numelec
           if (iind(thisconfig((j*2)-1:j*2)) == k) then
              tempflag=.true.;              exit
           endif
        enddo
        if (tempflag) then
           tempcount=tempcount+1
        endif
     enddo
  enddo
  if (tempcount.gt.vexcite) then
     allowedconfig=.false.;     return
  endif

  tempcount=0
  do ishell=1,numshells

     tempcount2=0
     do i=allshelltop(ishell-1)+1,allshelltop(ishell)  !! spatial orbital
        do ii=1,2 ! spin 

           k=iind((/ i,ii /))  ! spin orbital
           tempflag=.false.
           do j=1,numelec
              if (iind(thisconfig((j*2)-1:j*2)) == k) then  ! got this spin orbital in the configuration
                 tempflag=.true.
                 exit
              endif
           enddo
           if (.not.tempflag) then
!counts how many spin orbitals as of shell ishell are not included in the configuration
              tempcount=tempcount+1   
           else
!counts how many spin orbitals of shell ishell are included in the configuration
              tempcount2=tempcount2+1   
           endif
        enddo
     enddo
     if (tempcount2.gt.maxocc(ishell)) then
        allowedconfig=.false.;        return
     endif
     if (tempcount2.lt.minocc(ishell)) then
        allowedconfig=.false.;        return
     endif
     if (ishell.lt.numshells.and.tempcount.gt.numexcite(ishell)) then
        allowedconfig=.false.;        return
     endif
  enddo
  allowedconfig=.true.

end function allowedconfig


!! RETURNS M-VALUE OF CONFIGURATION

function getmval(thisconfig)
  use parameters
  implicit none
  integer :: thisconfig(ndof), i, isum, getmval
  if ((spfrestrictflag==0)) then
     getmval=0;     return
  endif
  isum=0
  do i=1,numelec*2-1,2
     isum=isum+(spfmvals(thisconfig(i)))
  enddo
  getmval=isum
end function getmval

!! RETURNS UGVAL OF CONFIGURATION (GOES FROM ORIGINAL UG VALUES)
!!  IF UGVALS ARE ALL SPECIFIED (NONZERO)

function getugval(thisconfig)
  use parameters
  implicit none
  integer :: thisconfig(ndof), i, isum, getugval
  isum=1
  do i=1,numelec*2-1,2
     isum=isum*(spfugvals(thisconfig(i)))
  enddo
  getugval=isum

end function getugval



!! GETS CONFIGURATION LIST (SLATER DETERMINANTS NOT SPIN EIGFUNCTS)
!!  AT BEGINNING. 



subroutine fast_newconfiglist(alreadycounted)
  use parameters
  use configmod
  use mpimod
  implicit none
  logical :: alreadycounted
  integer, parameter :: max_numelec=80
  integer, pointer :: &
       ii1,ii2,ii3,ii4,ii5,ii6,ii7,ii8,ii9,ii10, &
       ii11,ii12, ii13, ii14, ii15, ii16, ii17, ii18, ii19, ii20, &
       ii21,ii22, ii23, ii24, ii25, ii26, ii27, ii28, ii29, ii30, &
       ii31,ii32, ii33, ii34, ii35, ii36, ii37, ii38, ii39, ii40, &
       ii41,ii42, ii43, ii44, ii45, ii46, ii47, ii48, ii49, ii50, &
       ii51,ii52, ii53, ii54, ii55, ii56, ii57, ii58, ii59, ii60, &
       ii61,ii62, ii63, ii64, ii65, ii66, ii67, ii68, ii69, ii70, &
       ii71,ii72, ii73, ii74, ii75, ii76, ii77, ii78, ii79, ii80
  integer, pointer :: &
       jj1,jj2,jj3,jj4,jj5,jj6,jj7,jj8,jj9,jj10, &
       jj11,jj12, jj13, jj14, jj15, jj16, jj17, jj18, jj19, jj20, &
       jj21,jj22, jj23, jj24, jj25, jj26, jj27, jj28, jj29, jj30, &
       jj31,jj32, jj33, jj34, jj35, jj36, jj37, jj38, jj39, jj40, &
       jj41,jj42, jj43, jj44, jj45, jj46, jj47, jj48, jj49, jj50, &
       jj51,jj52, jj53, jj54, jj55, jj56, jj57, jj58, jj59, jj60, &
       jj61,jj62, jj63, jj64, jj65, jj66, jj67, jj68, jj69, jj70, &
       jj71,jj72, jj73, jj74, jj75, jj76, jj77, jj78, jj79, jj80
  integer, target :: iii(max_numelec)  !! no, it is set.
  integer, target :: jjj(max_numelec)  !! no, it is set.
  integer :: alltopwalks(nprocs),allbotwalks(nprocs)
  integer :: idof, ii , lowerarr(max_numelec),upperarr(max_numelec),  thisconfig(ndof),&
       reorder,nullint,kk,iconfig,mm, single(max_numelec),ishell,jj,maxssize=0,sss,nss,ssflag,numdoubly,&
       mynumexcite(0:numshells),isum,jshell
  logical :: allowedconfig

  if (numelec.gt.max_numelec) then
     OFLWR "Resize get_newconfiglist"; CFLST
  endif
  if (orderflag.eq.1) then
     OFLWR "orderflag 1 not supported for fastconfig (would be trivial, a simplification, no sort I think)"; CFLST
  endif

!!$ no, is ok, still using allowedconfig.
!!$  if (vexcite.ne.99) then
!!$     OFLWR "Vexcite not quite done for fastconfig"; CFLST
!!$  endif
!!$  if (mrestrictflag.ne.0.or.ugrestrictflag.ne.0.or.mrestrictmin.gt.-99999.or.mrestrictmax.lt.99999) then
!!$     OFLWR "Can't use mrestrictflag nor ugrestrictflag with fastconfig   nor mrestrictmin/max"; CFLST
!!$  endif
!!$  do ii=1,numshells
!!$     if ((minocc(ii).gt.0).or.(maxocc(ii).lt.2*(allshelltop(ii)-allshelltop(ii-1)))) then
!!$        OFLWR "can't use minocc or maxocc with fastconfig"; CFLST
!!$     endif
!!$  enddo


  if (alreadycounted) then
     OFLWR "Go fast_newconfiglist, getting configurations";CFL
     allocate(configlist(ndof,numconfig), configmvals(numconfig), configugvals(numconfig),&
          bigspinblockstart(numspinblocks+2*nprocs),bigspinblockend(numspinblocks+2*nprocs))
          
     configlist(:,:)=0; configmvals(:)=0;configugvals(:)=0
  else
     OFLWR "Go fast_newconfiglist";CFL
  endif

  ii1 => iii(1) ; ii2 => iii(2) ; ii3 => iii(3) ; ii4 => iii(4) ; ii5 => iii(5) ; ii6 => iii(6) ;
  ii7 => iii(7) ; ii8 => iii(8) ; ii9 => iii(9) ; ii10 => iii(10) ; ii11 => iii(11) ; ii12 => iii(12) ;
  ii13 => iii(13) ; ii14 => iii(14) ; ii15 => iii(15) ; ii16 => iii(16) ; ii17 => iii(17); ii18 => iii(18)
  ii19 => iii(19);ii20 => iii(20)

  ii21 => iii(21) ; ii22 => iii(22) ; ii23 => iii(23) ; ii24 => iii(24) ; ii25 => iii(25) ; ii26 => iii(26)
  ii27 => iii(27) ; ii28 => iii(28) ; ii29 => iii(29) ; ii30 => iii(30) ; ii31 => iii(31) ; ii32 => iii(32)
  ii33 => iii(33) ; ii34 => iii(34) ; ii35 => iii(35) ; ii36 => iii(36) ; ii37 => iii(37) ; ii38 => iii(38)
  ii39 => iii(39);ii40 => iii(40)

  ii41 => iii(41) ; ii42 => iii(42) ; ii43 => iii(43) ; ii44 => iii(44) ; ii45 => iii(45) ; ii46 => iii(46)
  ii47 => iii(47) ; ii48 => iii(48) ; ii49 => iii(49) ; ii50 => iii(50) ; ii51 => iii(51) ; ii52 => iii(52)
  ii53 => iii(53) ; ii54 => iii(54) ; ii55 => iii(55) ; ii56 => iii(56) ; ii57 => iii(57) ; ii58 => iii(58)
  ii59 => iii(59);ii60 => iii(60)

  ii61 => iii(61) ; ii62 => iii(62) ; ii63 => iii(63) ; ii64 => iii(64) ; ii65 => iii(65) ; ii66 => iii(66)
  ii67 => iii(67) ; ii68 => iii(68) ; ii69 => iii(69) ; ii70 => iii(70) ; ii71 => iii(71) ; ii72 => iii(72)
  ii73 => iii(73) ; ii74 => iii(74) ; ii75 => iii(75) ; ii76 => iii(76) ; ii77 => iii(77) ; ii78 => iii(78)
  ii79 => iii(79);  ii80 => iii(80)


  jj1 => jjj(1) ; jj2 => jjj(2) ; jj3 => jjj(3) ; jj4 => jjj(4) ; jj5 => jjj(5) ; jj6 => jjj(6) ;
  jj7 => jjj(7) ; jj8 => jjj(8) ; jj9 => jjj(9) ; jj10 => jjj(10) ; jj11 => jjj(11) ; jj12 => jjj(12) ;
  jj13 => jjj(13) ; jj14 => jjj(14) ; jj15 => jjj(15) ; jj16 => jjj(16) ; jj17 => jjj(17); jj18 => jjj(18)
  jj19 => jjj(19);jj20 => jjj(20)

  jj21 => jjj(21) ; jj22 => jjj(22) ; jj23 => jjj(23) ; jj24 => jjj(24) ; jj25 => jjj(25) ; jj26 => jjj(26)
  jj27 => jjj(27) ; jj28 => jjj(28) ; jj29 => jjj(29) ; jj30 => jjj(30) ; jj31 => jjj(31) ; jj32 => jjj(32)
  jj33 => jjj(33) ; jj34 => jjj(34) ; jj35 => jjj(35) ; jj36 => jjj(36) ; jj37 => jjj(37) ; jj38 => jjj(38)
  jj39 => jjj(39);jj40 => jjj(40)

  jj41 => jjj(41) ; jj42 => jjj(42) ; jj43 => jjj(43) ; jj44 => jjj(44) ; jj45 => jjj(45) ; jj46 => jjj(46)
  jj47 => jjj(47) ; jj48 => jjj(48) ; jj49 => jjj(49) ; jj50 => jjj(50) ; jj51 => jjj(51) ; jj52 => jjj(52)
  jj53 => jjj(53) ; jj54 => jjj(54) ; jj55 => jjj(55) ; jj56 => jjj(56) ; jj57 => jjj(57) ; jj58 => jjj(58)
  jj59 => jjj(59);jj60 => jjj(60)

  jj61 => jjj(61) ; jj62 => jjj(62) ; jj63 => jjj(63) ; jj64 => jjj(64) ; jj65 => jjj(65) ; jj66 => jjj(66)
  jj67 => jjj(67) ; jj68 => jjj(68) ; jj69 => jjj(69) ; jj70 => jjj(70) ; jj71 => jjj(71) ; jj72 => jjj(72)
  jj73 => jjj(73) ; jj74 => jjj(74) ; jj75 => jjj(75) ; jj76 => jjj(76) ; jj77 => jjj(77) ; jj78 => jjj(78)
  jj79 => jjj(79);  jj80 => jjj(80)


  lowerarr(:)=1000000
  upperarr(:)=1000000

  numdoubly=numelec-abs(restrictms)

  if (mod(numdoubly,2).ne.0) then
     OFLWR "OOGA NO!!"; CFLST
  endif

  do ii=1,numdoubly
     lowerarr(ii)=(ii+1)/2
  enddo
  do ii=1,abs(restrictms)
     lowerarr(ii+numdoubly)=numdoubly/2+ii
  enddo

  do ii=1,numelec
     upperarr(ii)=nspf+1-lowerarr(numelec+1-ii)
  enddo


!  do ii=1,numelec
!     lowerarr(ii)=(ii+1)/2
!     upperarr(ii)=nspf-(numelec-ii)/2
!  enddo

  do ii=numelec+3,max_numelec
     upperarr(ii)=1000000+ii-numelec+2
     lowerarr(ii)=1000000+ii-numelec+2
  enddo

!!#          min        max
!!numelec     ..        nspf
!!numelec+1  1000000    1000000
!!numelec+2  1000000    1000000
!!numelec+3  1000001    1000001  etc.
!!numelec+4  1000002    1000002
!!numelec+4  1000003    1000003

!!account for numexcite and vexcite only; not minocc, nor maxocc
!! numexcite(:) is CUMULATIVE
!! vexcite only for last shell   not debugged

!! Now account for maxocc 05-05-2015

  mynumexcite(0)=0

  do ishell=1,numshells
     isum=0
     do jshell=1,numshells
        if (jshell.ne.ishell) then
           isum=isum+min(maxocc(jshell),2*(allshelltop(jshell)-allshelltop(jshell-1)))
        endif
     enddo
!! minimum number of electrons in shell ishell is now numelec-isum
!!   maximum number of holes is 2*(shelltop(ishell)-shelltop(ishell-1))-(numelec-isum)     

     mynumexcite(ishell)=min(numexcite(ishell),mynumexcite(ishell-1)+ &
          max(0,2*(allshelltop(ishell)-allshelltop(ishell-1))-(numelec-isum)))
  enddo

  OFLWR "Numexcite, mynumexcite"
  do ishell=1,numshells
     WRFL ishell,numexcite(ishell),mynumexcite(ishell)
  enddo
  CFL
     
!!!!!!

  kk=0
  do ishell=1,numshells
     mm=2*allshelltop(ishell)-min(mynumexcite(ishell),2*nspf-numelec)
     do jj=kk+1,mm

!!        upperarr(jj)=allshelltop(ishell)-(mm-jj)/2

        upperarr(jj)=min(upperarr(jj),allshelltop(ishell)-(mm-jj)/2)

     enddo
     kk=max(0,mm)
  enddo

  if (.not.alreadycounted) then
     OFLWR "UPPER/LOWER"
     do ii=1,numelec
        WRFL lowerarr(ii),upperarr(ii)
     enddo
     WRFL; CFL
  endif

  iconfig=0
  nss=0
  maxssize=0
  ssflag=1

  do ii1=  lowerarr(1),upperarr(1)
  do ii2=      max(lowerarr(2), ii1)         ,upperarr(2)
  do ii3=  max(max(lowerarr(3) ,ii2),ii1 +1 ),upperarr(3)
  do ii4=  max(max(lowerarr(4) ,ii3 ),ii2 +1 ),upperarr(4)
  do ii5=  max(max(lowerarr(5) ,ii4 ),ii3 +1 ),upperarr(5)
  do ii6=  max(max(lowerarr(6) ,ii5 ),ii4 +1 ),upperarr(6)
  do ii7=  max(max(lowerarr(7) ,ii6 ),ii5 +1 ),upperarr(7)
  do ii8=  max(max(lowerarr(8) ,ii7 ),ii6 +1 ),upperarr(8)
  do ii9=  max(max(lowerarr(9) ,ii8 ),ii7 +1 ),upperarr(9)

  do ii10= max(max(lowerarr(10),ii9 ),ii8 +1 ),upperarr(10)
  do ii11= max(max(lowerarr(11),ii10),ii9 +1 ),upperarr(11)
  do ii12= max(max(lowerarr(12),ii11),ii10+1 ),upperarr(12)
  do ii13= max(max(lowerarr(13),ii12),ii11+1 ),upperarr(13)
  do ii14= max(max(lowerarr(14),ii13),ii12+1 ),upperarr(14)
  do ii15= max(max(lowerarr(15),ii14),ii13+1 ),upperarr(15)
  do ii16= max(max(lowerarr(16),ii15),ii14+1 ),upperarr(16)
  do ii17= max(max(lowerarr(17),ii16),ii15+1 ),upperarr(17)
  do ii18= max(max(lowerarr(18),ii17),ii16+1 ),upperarr(18)
  do ii19= max(max(lowerarr(19),ii18),ii17+1 ),upperarr(19)

  do ii20= max(max(lowerarr(20),ii19),ii18+1),upperarr(20)
  do ii21= max(max(lowerarr(21),ii20),ii19+1),upperarr(21)
  do ii22= max(max(lowerarr(22),ii21),ii20+1),upperarr(22)
  do ii23= max(max(lowerarr(23),ii22),ii21+1),upperarr(23)
  do ii24= max(max(lowerarr(24),ii23),ii22+1),upperarr(24)
  do ii25= max(max(lowerarr(25),ii24),ii23+1),upperarr(25)
  do ii26= max(max(lowerarr(26),ii25),ii24+1),upperarr(26)
  do ii27= max(max(lowerarr(27),ii26),ii25+1),upperarr(27)
  do ii28= max(max(lowerarr(28),ii27),ii26+1),upperarr(28)
  do ii29= max(max(lowerarr(29),ii28),ii27+1),upperarr(29)

  do ii30= max(max(lowerarr(30),ii29),ii28+1),upperarr(30)
  do ii31= max(max(lowerarr(31),ii30),ii29+1),upperarr(31)
  do ii32= max(max(lowerarr(32),ii31),ii30+1),upperarr(32)
  do ii33= max(max(lowerarr(33),ii32),ii31+1),upperarr(33)
  do ii34= max(max(lowerarr(34),ii33),ii32+1),upperarr(34)
  do ii35= max(max(lowerarr(35),ii34),ii33+1),upperarr(35)
  do ii36= max(max(lowerarr(36),ii35),ii34+1),upperarr(36)
  do ii37= max(max(lowerarr(37),ii36),ii35+1),upperarr(37)
  do ii38= max(max(lowerarr(38),ii37),ii36+1),upperarr(38)
  do ii39= max(max(lowerarr(39),ii38),ii37+1),upperarr(39)

  do ii40= max(max(lowerarr(40),ii39),ii38+1),upperarr(40)
  do ii41= max(max(lowerarr(41),ii40),ii39+1),upperarr(41)
  do ii42= max(max(lowerarr(42),ii41),ii40+1),upperarr(42)
  do ii43= max(max(lowerarr(43),ii42),ii41+1),upperarr(43)
  do ii44= max(max(lowerarr(44),ii43),ii42+1),upperarr(44)
  do ii45= max(max(lowerarr(45),ii44),ii43+1),upperarr(45)
  do ii46= max(max(lowerarr(46),ii45),ii44+1),upperarr(46)
  do ii47= max(max(lowerarr(47),ii46),ii45+1),upperarr(47)
  do ii48= max(max(lowerarr(48),ii47),ii46+1),upperarr(48)
  do ii49= max(max(lowerarr(49),ii48),ii47+1),upperarr(49)

  do ii50= max(max(lowerarr(50),ii49),ii48+1),upperarr(50)
  do ii51= max(max(lowerarr(51),ii50),ii49+1),upperarr(51)
  do ii52= max(max(lowerarr(52),ii51),ii50+1),upperarr(52)
  do ii53= max(max(lowerarr(53),ii52),ii51+1),upperarr(53)
  do ii54= max(max(lowerarr(54),ii53),ii52+1),upperarr(54)
  do ii55= max(max(lowerarr(55),ii54),ii53+1),upperarr(55)
  do ii56= max(max(lowerarr(56),ii55),ii54+1),upperarr(56)
  do ii57= max(max(lowerarr(57),ii56),ii55+1),upperarr(57)
  do ii58= max(max(lowerarr(58),ii57),ii56+1),upperarr(58)
  do ii59= max(max(lowerarr(59),ii58),ii57+1),upperarr(59)

  do ii60= max(max(lowerarr(60),ii59),ii58+1),upperarr(60)
  do ii61= max(max(lowerarr(61),ii60),ii59+1),upperarr(61)
  do ii62= max(max(lowerarr(62),ii61),ii60+1),upperarr(62)
  do ii63= max(max(lowerarr(63),ii62),ii61+1),upperarr(63)
  do ii64= max(max(lowerarr(64),ii63),ii62+1),upperarr(64)
  do ii65= max(max(lowerarr(65),ii64),ii63+1),upperarr(65)
  do ii66= max(max(lowerarr(66),ii65),ii64+1),upperarr(66)
  do ii67= max(max(lowerarr(67),ii66),ii65+1),upperarr(67)
  do ii68= max(max(lowerarr(68),ii67),ii66+1),upperarr(68)
  do ii69= max(max(lowerarr(69),ii68),ii67+1),upperarr(69)

  do ii70= max(max(lowerarr(70),ii69),ii68+1),upperarr(70)
  do ii71= max(max(lowerarr(71),ii70),ii69+1),upperarr(71)
  do ii72= max(max(lowerarr(72),ii71),ii70+1),upperarr(72)
  do ii73= max(max(lowerarr(73),ii72),ii71+1),upperarr(73)
  do ii74= max(max(lowerarr(74),ii73),ii72+1),upperarr(74)
  do ii75= max(max(lowerarr(75),ii74),ii73+1),upperarr(75)
  do ii76= max(max(lowerarr(76),ii75),ii74+1),upperarr(76)
  do ii77= max(max(lowerarr(77),ii76),ii75+1),upperarr(77)
  do ii78= max(max(lowerarr(78),ii77),ii76+1),upperarr(78)
  do ii79= max(max(lowerarr(79),ii78),ii77+1),upperarr(79)

  do ii80= max(max(lowerarr(80),ii79),ii78+1),upperarr(80)

  if (okexcite(iii)) then
     sss=0
     ssflag=0

     do idof=1,numelec
        thisconfig(idof*2-1) = iii(idof)
     enddo

     single(:)=1
     single(numelec+1:)=0

     do idof=2,numelec
        if (iii(idof).eq.iii(idof-1)) then
           thisconfig((idof-1)*2)=1
           thisconfig(idof*2)=2
           single(idof-1)=0
           single(idof)=0
        endif
     enddo

     do jj1=0,single(1)
     do jj2=0,single(2)
     do jj3=0,single(3)
     do jj4=0,single(4)
     do jj5=0,single(5)
     do jj6=0,single(6)
     do jj7=0,single(7)
     do jj8=0,single(8)
     do jj9=0,single(9)
     do jj10=0,single(10)

     do jj11=0,single(11)
     do jj12=0,single(12)
     do jj13=0,single(13)
     do jj14=0,single(14)
     do jj15=0,single(15)
     do jj16=0,single(16)
     do jj17=0,single(17)
     do jj18=0,single(18)
     do jj19=0,single(19)
     do jj20=0,single(20)

     do jj21=0,single(21)
     do jj22=0,single(22)
     do jj23=0,single(23)
     do jj24=0,single(24)
     do jj25=0,single(25)
     do jj26=0,single(26)
     do jj27=0,single(27)
     do jj28=0,single(28)
     do jj29=0,single(29)
     do jj30=0,single(30)

     do jj31=0,single(31)
     do jj32=0,single(32)
     do jj33=0,single(33)
     do jj34=0,single(34)
     do jj35=0,single(35)
     do jj36=0,single(36)
     do jj37=0,single(37)
     do jj38=0,single(38)
     do jj39=0,single(39)
     do jj40=0,single(40)

     do jj41=0,single(41)
     do jj42=0,single(42)
     do jj43=0,single(43)
     do jj44=0,single(44)
     do jj45=0,single(45)
     do jj46=0,single(46)
     do jj47=0,single(47)
     do jj48=0,single(48)
     do jj49=0,single(49)
     do jj50=0,single(50)

     do jj51=0,single(51)
     do jj52=0,single(52)
     do jj53=0,single(53)
     do jj54=0,single(54)
     do jj55=0,single(55)
     do jj56=0,single(56)
     do jj57=0,single(57)
     do jj58=0,single(58)
     do jj59=0,single(59)
     do jj60=0,single(60)

     do jj61=0,single(61)
     do jj62=0,single(62)
     do jj63=0,single(63)
     do jj64=0,single(64)
     do jj65=0,single(65)
     do jj66=0,single(66)
     do jj67=0,single(67)
     do jj68=0,single(68)
     do jj69=0,single(69)
     do jj70=0,single(70)

     do jj71=0,single(71)
     do jj72=0,single(72)
     do jj73=0,single(73)
     do jj74=0,single(74)
     do jj75=0,single(75)
     do jj76=0,single(76)
     do jj77=0,single(77)
     do jj78=0,single(78)
     do jj79=0,single(79)
     do jj80=0,single(80)

        do idof=1,numelec
           if (single(idof).eq.1) then
              thisconfig(idof*2)=jjj(idof)+1
           endif
        enddo

        if (allowedconfig(thisconfig)) then
           sss=sss+1
           iconfig=iconfig+1
           if (ssflag.eq.0) then 
              nss=nss+1
              ssflag=1
              if (alreadycounted) then 
                 bigspinblockstart(nss)=iconfig
              endif
           endif
           if (alreadycounted) then
              bigspinblockend(nss)=iconfig
              configlist(:,iconfig)=thisconfig; 
              nullint=reorder(configlist(:,iconfig))
           endif
        endif


  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo

  if (sss.gt.maxssize) then
     maxssize=sss
  endif
endif

  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo
  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo;  enddo

!  if (alreadycounted) then
!     OFLWR "BIGSPINCHECK"
!     do ii=1,numspinblocks
!        WRFL bigspinblockstart(ii),bigspinblockend(ii)
!     enddo
!     WRFL "TEMPSTOP"; CFLST
!  endif



  if (alreadycounted) then
     if (iconfig/=numconfig) then
        OFLWR "Configlist err",iconfig,numconfig; CFLST
     endif

     OFLWR "     ...Done fast_newconfiglist"; CFL
  else
     numconfig=iconfig
     OFLWR; WRFL "FASTNEWCONFIG: NUMBER OF CONFIGURATIONS ",numconfig; WRFL; CFL
     if (numconfig.le.0) then
        OFLWR "NO configs."; CFLST
     endif
  endif

  if (alreadycounted) then
     if (nss.ne.numspinblocks) then
        OFLWR "NUMSPINBLOCKS ERR",nss,numspinblocks; CFLST
     endif
!     bigspinblockend(numspinblocks)=numconfig
!     do ii=1,numspinblocks-1
!        bigspinblockend(ii)=bigspinblockstart(ii+1)-1
!     enddo

     if (sparseconfigflag.eq.0) then
        allbotwalks=1
        alltopwalks=numconfig
     else
        alltopwalks(:)=0
        jj=1
        do ii=1,nprocs-1
           do while (bigspinblockend(jj).lt.numconfig*ii/nprocs)
              alltopwalks(ii:)=bigspinblockend(jj)
              jj=jj+1
           enddo
        enddo
        alltopwalks(nprocs)=numconfig
        allbotwalks(1)=1
        do ii=2,nprocs
           allbotwalks(ii)=alltopwalks(ii-1)+1
        enddo
     endif
     OFLWR; WRFL "BOTWALKS /TOPWALKS",numconfig
     do ii=1,nprocs
        WRFL allbotwalks(ii),alltopwalks(ii),alltopwalks(ii)-allbotwalks(ii)+1
     enddo
     WRFL; CFL
     do ii=1,nprocs     
!! WOULD BE NICE BUT NO, NO +1 - canNOT be bot=1,top=0 for range=0.  range not negative. RANGE POSITIVE
!! would be nice        if (allbotwalks(ii).gt.alltopwalks(ii)+1) then     ...or not
        if (allbotwalks(ii).gt.alltopwalks(ii)+1) then   
           OFLWR "ERROR, NUMBER OF CONFIGS PROCESSOR ",ii," IS LESS THAN ZERO", alltopwalks(ii)-allbotwalks(ii)+1 ;CFLST
        endif
     enddo

     botwalk=allbotwalks(myrank)
     topwalk=alltopwalks(myrank)
  else
     numspinblocks=nss
     maxspinblocksize=maxssize
     OFLWR "NUMSPINBLOCKS, MAXSPINBLOCKSIZE FASTCONFIG",nss,maxssize;CFL
  endif

  if (alreadycounted.and.iprintconfiglist.ne.0) then
     OFLWR "CONFIGLIST"
     do ii=1,numconfig
!        write(mpifileptr,'(A12,I12,A4)',advance='no') "  Config ", ii," is "
        write(mpifileptr,'(A12,I12,A4)',advance='no') "  Config ", 0," is "
        call printconfig(configlist(:,ii))
     enddo
     WRFL; CFLST
  endif

        
  

contains
  function okexcite(jjj)
    implicit none
    logical :: okexcite
    integer :: jjj(numelec),ii,ishell    !! numelec*2=ndof
    integer :: numwithinshell(numshells),kkk(numelec)
    numwithinshell(:)=0
    kkk(:)=(jjj(:)+1)/2   !! orderflag 0
    do ii=1,numelec
       do ishell=1,numshells
          if (kkk(ii).gt.allshelltop(ishell)) then
             exit
          else
             numwithinshell(ishell)=numwithinshell(ishell)+1
          endif
       enddo
    enddo
    do ishell=1,numshells
       if (numwithinshell(ishell).lt.2*allshelltop(ishell)-numexcite(ishell)) then
          okexcite=.false.
          return
       endif
    enddo
    okexcite=.true.
  end function okexcite

  function quickaarr(xind)
    implicit none
    integer, dimension(2) :: quickaarr
    integer, save :: temp(2)
    integer :: ind,q, xind

    ind=xind-1
!orderflag 0
    temp(2)           = mod(ind,2)+1
!!       q=(ind-mod(ind,2))/2  no need
    q=ind/2                   !! rounds down.
    temp(1)           = q+1
    quickaarr=temp
  end function quickaarr

end subroutine fast_newconfiglist





