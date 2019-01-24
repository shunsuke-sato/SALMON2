!
!  Copyright 2017 SALMON developers
!
!  Licensed under the Apache License, Version 2.0 (the "License");
!  you may not use this file except in compliance with the License.
!  You may obtain a copy of the License at
!
!      http://www.apache.org/licenses/LICENSE-2.0
!
!  Unless required by applicable law or agreed to in writing, software
!  distrisuted under the License is distrisuted on an "AS IS" BASIS,
!  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
!  See the License for the specific language governing permissions and
!  limitations under the License.
!
module update_overlap_sub

contains

!===================================================================================================================================

subroutine update_overlap_R(tpsi,is_array,ie_array,Norb,Nd,is,ie,irank_overlap,icomm)
  use salmon_communication, only: comm_proc_null, comm_isend, comm_irecv, comm_wait_all
  implicit none
  integer,intent(in) :: is_array(3),ie_array(3),Norb,Nd,is(3),ie(3),irank_overlap(6),icomm
  real(8) :: tpsi(is_array(1):ie_array(1),is_array(2):ie_array(2),is_array(3):ie_array(3),1:Norb)
  !
  integer :: ix,iy,iz,iorb
  integer :: iup,idw,jup,jdw,kup,kdw
  integer :: ireq(12)

  real(8),allocatable :: commbuf_x(:,:,:,:,:),commbuf_y(:,:,:,:,:),commbuf_z(:,:,:,:,:)

  iup = irank_overlap(1)
  idw = irank_overlap(2)
  jup = irank_overlap(3)
  jdw = irank_overlap(4)
  kup = irank_overlap(5)
  kdw = irank_overlap(6)

  allocate(commbuf_x(Nd,ie(2)-is(2)+1,ie(3)-is(3)+1,Norb,4))
  allocate(commbuf_y(ie(1)-is(1)+1,Nd,ie(3)-is(3)+1,Norb,4))
  allocate(commbuf_z(ie(1)-is(1)+1,ie(2)-is(2)+1,Nd,Norb,4))

  !send from idw to iup

  if(iup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix) 
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        commbuf_x(ix,iy,iz,iorb,1)=tpsi(ie(1)-Nd+ix,iy+is(2)-1,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(1) = comm_isend(commbuf_x(:,:,:,:,1:1),iup,3,icomm)
  ireq(2) = comm_irecv(commbuf_x(:,:,:,:,2:2),idw,3,icomm)

  !send from iup to idw

  if(idw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        commbuf_x(ix,iy,iz,iorb,3)=tpsi(is(1)+ix-1,iy+is(2)-1,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(3) = comm_isend(commbuf_x(:,:,:,:,3:3),idw,4,icomm)
  ireq(4) = comm_irecv(commbuf_x(:,:,:,:,4:4),iup,4,icomm)

  !send from jdw to jup

  if(jup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix) 
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        commbuf_y(ix,iy,iz,iorb,1)=tpsi(ix+is(1)-1,ie(2)-Nd+iy,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(5) = comm_isend(commbuf_y(:,:,:,:,1:1),jup,5,icomm)
  ireq(6) = comm_irecv(commbuf_y(:,:,:,:,2:2),jdw,5,icomm)

  !send from jup to jdw

  if(jdw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        commbuf_y(ix,iy,iz,iorb,3)=tpsi(ix+is(1)-1,is(2)+iy-1,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(7) = comm_isend(commbuf_y(:,:,:,:,3:3),jdw,6,icomm)
  ireq(8) = comm_irecv(commbuf_y(:,:,:,:,4:4),jup,6,icomm)

  !send from kdw to kup

  if(kup/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix)
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        commbuf_z(ix,iy,iz,iorb,1)=tpsi(ix+is(1)-1,iy+is(2)-1,ie(3)-Nd+iz,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq( 9) = comm_isend(commbuf_z(:,:,:,:,1:1),kup,7,icomm)
  ireq(10) = comm_irecv(commbuf_z(:,:,:,:,2:2),kdw,7,icomm)

  !send from kup to kdw

  if(kdw/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix) 
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        commbuf_z(ix,iy,iz,iorb,3)=tpsi(ix+is(1)-1,iy+is(2)-1,is(3)+iz-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(11) = comm_isend(commbuf_z(:,:,:,:,3:3),kdw,8,icomm)
  ireq(12) = comm_irecv(commbuf_z(:,:,:,:,4:4),kup,8,icomm)


  call comm_wait_all(ireq(1:2))
  if(idw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        tpsi(is(1)-1-Nd+ix,iy+is(2)-1,iz+is(3)-1,iorb)=commbuf_x(ix,iy,iz,iorb,2)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(3:4))
  if(iup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        tpsi(ie(1)+ix,iy+is(2)-1,iz+is(3)-1,iorb)=commbuf_x(ix,iy,iz,iorb,4)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(5:6))
  if(jdw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,is(2)-1-Nd+iy,iz+is(3)-1,iorb)=commbuf_y(ix,iy,iz,iorb,2)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(7:8))
  if(jup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix) 
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,ie(2)+iy,iz+is(3)-1,iorb)=commbuf_y(ix,iy,iz,iorb,4)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(9:10))
  if(kdw/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix) 
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,iy+is(2)-1,is(3)-1-Nd+iz,iorb)=commbuf_z(ix,iy,iz,iorb,2)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(11:12))
  if(kup/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix)
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,iy+is(2)-1,ie(3)+iz,iorb)=commbuf_z(ix,iy,iz,iorb,4)
      end do
      end do
      end do
    end do
  end if

  deallocate(commbuf_x,commbuf_y,commbuf_z)

  return
end subroutine update_overlap_R

!===================================================================================================================================

subroutine update_overlap_C(tpsi,is_array,ie_array,Norb,Nd,is,ie,irank_overlap,icomm)
  use salmon_communication, only: comm_proc_null, comm_isend, comm_irecv, comm_wait_all
  implicit none
  integer,intent(in) :: is_array(3),ie_array(3),Norb,Nd,is(3),ie(3),irank_overlap(6),icomm
  complex(8) :: tpsi(is_array(1):ie_array(1),is_array(2):ie_array(2),is_array(3):ie_array(3),1:Norb)
  !
  integer :: ix,iy,iz,iorb
  integer :: iup,idw,jup,jdw,kup,kdw
  integer :: ireq(12)

  complex(8),allocatable :: commbuf_x(:,:,:,:,:),commbuf_y(:,:,:,:,:),commbuf_z(:,:,:,:,:)

  iup = irank_overlap(1)
  idw = irank_overlap(2)
  jup = irank_overlap(3)
  jdw = irank_overlap(4)
  kup = irank_overlap(5)
  kdw = irank_overlap(6)

  allocate(commbuf_x(Nd,ie(2)-is(2)+1,ie(3)-is(3)+1,Norb,4))
  allocate(commbuf_y(ie(1)-is(1)+1,Nd,ie(3)-is(3)+1,Norb,4))
  allocate(commbuf_z(ie(1)-is(1)+1,ie(2)-is(2)+1,Nd,Norb,4))

  !send from idw to iup

  if(iup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix) 
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        commbuf_x(ix,iy,iz,iorb,1)=tpsi(ie(1)-Nd+ix,iy+is(2)-1,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(1) = comm_isend(commbuf_x(:,:,:,:,1:1),iup,3,icomm)
  ireq(2) = comm_irecv(commbuf_x(:,:,:,:,2:2),idw,3,icomm)

  !send from iup to idw

  if(idw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        commbuf_x(ix,iy,iz,iorb,3)=tpsi(is(1)+ix-1,iy+is(2)-1,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(3) = comm_isend(commbuf_x(:,:,:,:,3:3),idw,4,icomm)
  ireq(4) = comm_irecv(commbuf_x(:,:,:,:,4:4),iup,4,icomm)

  !send from jdw to jup

  if(jup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix) 
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        commbuf_y(ix,iy,iz,iorb,1)=tpsi(ix+is(1)-1,ie(2)-Nd+iy,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(5) = comm_isend(commbuf_y(:,:,:,:,1:1),jup,5,icomm)
  ireq(6) = comm_irecv(commbuf_y(:,:,:,:,2:2),jdw,5,icomm)

  !send from jup to jdw

  if(jdw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        commbuf_y(ix,iy,iz,iorb,3)=tpsi(ix+is(1)-1,is(2)+iy-1,iz+is(3)-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(7) = comm_isend(commbuf_y(:,:,:,:,3:3),jdw,6,icomm)
  ireq(8) = comm_irecv(commbuf_y(:,:,:,:,4:4),jup,6,icomm)

  !send from kdw to kup

  if(kup/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix)
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        commbuf_z(ix,iy,iz,iorb,1)=tpsi(ix+is(1)-1,iy+is(2)-1,ie(3)-Nd+iz,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq( 9) = comm_isend(commbuf_z(:,:,:,:,1:1),kup,7,icomm)
  ireq(10) = comm_irecv(commbuf_z(:,:,:,:,2:2),kdw,7,icomm)

  !send from kup to kdw

  if(kdw/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix) 
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        commbuf_z(ix,iy,iz,iorb,3)=tpsi(ix+is(1)-1,iy+is(2)-1,is(3)+iz-1,iorb)
      end do
      end do
      end do
    end do
  end if
  ireq(11) = comm_isend(commbuf_z(:,:,:,:,3:3),kdw,8,icomm)
  ireq(12) = comm_irecv(commbuf_z(:,:,:,:,4:4),kup,8,icomm)


  call comm_wait_all(ireq(1:2))
  if(idw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        tpsi(is(1)-1-Nd+ix,iy+is(2)-1,iz+is(3)-1,iorb)=commbuf_x(ix,iy,iz,iorb,2)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(3:4))
  if(iup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,ie(2)-is(2)+1
      do ix=1,Nd
        tpsi(ie(1)+ix,iy+is(2)-1,iz+is(3)-1,iorb)=commbuf_x(ix,iy,iz,iorb,4)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(5:6))
  if(jdw/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix)
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,is(2)-1-Nd+iy,iz+is(3)-1,iorb)=commbuf_y(ix,iy,iz,iorb,2)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(7:8))
  if(jup/=comm_proc_null)then
    do iorb=1,Norb
  !$OMP parallel do private(iz,iy,ix) 
      do iz=1,ie(3)-is(3)+1
      do iy=1,Nd
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,ie(2)+iy,iz+is(3)-1,iorb)=commbuf_y(ix,iy,iz,iorb,4)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(9:10))
  if(kdw/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix) 
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,iy+is(2)-1,is(3)-1-Nd+iz,iorb)=commbuf_z(ix,iy,iz,iorb,2)
      end do
      end do
      end do
    end do
  end if

  call comm_wait_all(ireq(11:12))
  if(kup/=comm_proc_null)then
    do iorb=1,Norb
      do iz=1,Nd
  !$OMP parallel do private(iy,ix)
      do iy=1,ie(2)-is(2)+1
      do ix=1,ie(1)-is(1)+1
        tpsi(ix+is(1)-1,iy+is(2)-1,ie(3)+iz,iorb)=commbuf_z(ix,iy,iz,iorb,4)
      end do
      end do
      end do
    end do
  end if

  deallocate(commbuf_x,commbuf_y,commbuf_z)

  return
end subroutine update_overlap_C

!===================================================================================================================================

end module update_overlap_sub
