!==========================================================================================!
!==========================================================================================!
!  Module stable_cohorts
!
!> \brief   Sub-routine and functions that flag whether cohorts are resolvable or not
!> \details These routines and functions define two logical flags (leaf_resolvable and 
!>          wood_resolvable) that will decide whether cohorts can be solved in the water,
!>          energy, and CO2 budget.  These flags ensure that the cohort is consistently
!>          skipped or resolved.
!------------------------------------------------------------------------------------------!
module stable_cohorts
   contains

   !=======================================================================================!
   !=======================================================================================!
   !     This subroutine will go through all cohorts in a polygon, and assign them as      !
   ! either numerically safe or unsafe.  The idea of to use a unique test to decide which  !
   ! cohorts we will solve in photosynthesis, radiation, and the energy balance (RK4 or    !
   ! Euler).                                                                               !
   !---------------------------------------------------------------------------------------!
   subroutine flag_stable_cohorts(cgrid)
      use ed_state_vars         , only : edtype          & ! structure
                                       , polygontype     & ! structure
                                       , sitetype        & ! structure
                                       , patchtype       ! ! structure
      implicit none
      !----- Arguments --------------------------------------------------------------------!
      type(edtype)     , target   :: cgrid         ! Current grid
      !----- Local variables. -------------------------------------------------------------!
      type(polygontype), pointer  :: cpoly         ! Current polygon
      type(sitetype)   , pointer  :: csite         ! Current site
      type(patchtype)  , pointer  :: cpatch        ! Current patch
      integer                     :: ipy           ! Polygon index
      integer                     :: isi           ! Site index
      integer                     :: ipa           ! Patch index
      integer                     :: ico           ! Cohort index
      !------------------------------------------------------------------------------------!

      polyloop: do ipy=1, cgrid%npolygons

         cpoly => cgrid%polygon(ipy)
         siteloop: do isi=1,cpoly%nsites

            csite => cpoly%site(isi)
            patchloop: do ipa=1,csite%npatches
               cpatch => csite%patch(ipa)

               cohortloop: do ico=1, cpatch%ncohorts

                  !----- Check whether we can resolve this cohort. ------------------------!
                  call is_resolvable(csite,ipa,ico)
                  !------------------------------------------------------------------------!

               end do cohortloop
               !---------------------------------------------------------------------------!
            end do patchloop
         end do siteloop
      end do polyloop

      return
   end subroutine flag_stable_cohorts
   !=======================================================================================!
   !=======================================================================================!






   !=======================================================================================!
   !=======================================================================================!
   !     This sub-routine checks whether cohort leaves and wood thermodynamics can or can- !
   ! not be solved.  This was taken out of flag_stable_cohorts so we can call it in other  !
   ! places and change the cohort status as soon as the conditions change.  We will skip   !
   ! the cohort if any of these conditions happens:                                        !
   ! 1. The cohort leaf biomass is much less than what it would have when all              !
   !    leaves are fully flushed (leaves only);                                            !
   ! 2. The cohort is buried in snow or under water                                        !
   ! 3. The cohort is extremely sparse.                                                    !
   ! 4. The user doesn't want to solve wood thermodynamics (wood only).                    !
   !---------------------------------------------------------------------------------------!
   subroutine is_resolvable(csite,ipa,ico)
      use ed_state_vars  , only : sitetype            & ! structure
                                , patchtype           ! ! structure
      use pft_coms       , only : veg_hcap_min        ! ! intent(in)
      use ed_max_dims    , only : n_pft               ! ! intent(in)
      use physiology_coms, only : plant_hydro_scheme  ! ! intent(in)

      implicit none
      !----- Arguments --------------------------------------------------------------------!
      type(sitetype)        , target     :: csite        ! Current site
      integer               , intent(in) :: ipa          ! Patch index
      integer               , intent(in) :: ico          ! Cohort index
      !----- Local variables. -------------------------------------------------------------!
      type(patchtype)  , pointer :: cpatch       ! Current patch
      integer                    :: ipft         ! Cohort PFT
      logical                    :: exposed      ! Cohort is above snow            [   T|F]
      logical                    :: leaf_enough  ! Cohort have enough leaves       [   T|F]
      logical                    :: wood_enough  ! Cohort have enough wood         [   T|F]
      logical                    :: hydro_req    ! Plant hydraulics requirement    [   T|F]
      !------------------------------------------------------------------------------------!


      cpatch => csite%patch(ipa)

      ipft      = cpatch%pft(ico)

      !------------------------------------------------------------------------------------!
      ! 1.  Check for cohort height relative to snow/water depth.  If the cohort is buried !
      !     in snow or has drowned in the standing water, we can't solve it.               !
      !------------------------------------------------------------------------------------!
      exposed      = cpatch%hite(ico)  > csite%total_sfcw_depth(ipa)
      !------------------------------------------------------------------------------------!



      !------------------------------------------------------------------------------------!
      ! 2.   Check whether this cohort is not extremely sparse.  Wood area heat capacity   !
      !      is always set to zero when branch thermodynamics is turned off, so this will  !
      !      always be .false. in this case.                                               !
      !------------------------------------------------------------------------------------!
      leaf_enough  = cpatch%leaf_hcap(ico) > veg_hcap_min(ipft)
      wood_enough  = cpatch%wood_hcap(ico) > veg_hcap_min(ipft)
      !------------------------------------------------------------------------------------!



      !------------------------------------------------------------------------------------!
      ! 3.   In case dynamic plant hydraulics is active, wood must be resolved whenever    !
      !      leaf is resolved.                                                             !
      !------------------------------------------------------------------------------------!
      select case (plant_hydro_scheme)
      case (0)
         hydro_req = .false.
      case default
         hydro_req = leaf_enough
      end select
      !------------------------------------------------------------------------------------!



      !------------------------------------------------------------------------------------!
      !     Save the tests in the cohort variable, so the checks are done consistently.    !
      !------------------------------------------------------------------------------------!
      cpatch%leaf_resolvable(ico) = exposed .and. leaf_enough
      cpatch%wood_resolvable(ico) = exposed .and. ( wood_enough .or. hydro_req )
      !------------------------------------------------------------------------------------!


      return
   end subroutine is_resolvable
   !=======================================================================================!
   !=======================================================================================!
end module stable_cohorts
!==========================================================================================!
!==========================================================================================!
