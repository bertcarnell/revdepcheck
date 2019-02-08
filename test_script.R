pkg <- "lhs"
pkg_path <- "../lhs"
dependencies <- "Depends"

################################################################################
# Create directory structure
check_and_create_dir <- function(newdir)
{
  if (!file.exists(newdir))
  {
    dir.create(newdir, recursive = TRUE)
  }
  return(newdir)
}
revdep_path <- check_and_create_dir(file.path(pkg_path, "revdep"))
revdep_library_path <- check_and_create_dir(file.path(revdep_path, "library", "lhs"))
revdep_library_path_new <- check_and_create_dir(file.path(revdep_library_path, "new"))
revdep_library_path_old <- check_and_create_dir(file.path(revdep_library_path, "old"))
revdep_check_path <- check_and_create_dir(file.path(revdep_path, "checks"))

################################################################################
# install old package and dependencies
deps <- tools::package_dependencies(pkg)[[pkg]]

install.packages(pkg, lib = revdep_library_path_old)
install.packages(deps, lib = revdep_library_path_old)

################################################################################
# install new package and dependencies
out <- callr::rcmd("build", cmdargs = pkg_path)
assertthat::assert_that(out$status == 0)
pkg_tar_ball <- list.files(path = '.', pattern = pkg)
install.packages(pkg_tar_ball, lib = revdep_library_path_new, repos = NULL)
install.packages(deps, lib = revdep_library_path_new)

################################################################################
# check reverse dependencies
revdeps <- devtools::revdep(pkg = pkg, dependencies = dependencies)

rcmd_output_new <- vector("list", length(revdeps))
rcmd_output_old <- vector("list", length(revdeps))
for (i in seq_along(revdeps))
{
  revdep <- revdeps[i]
  revdep_check_path_curr <- check_and_create_dir(file.path(revdep_check_path, revdep))
  revdep_check_path_curr_old <- check_and_create_dir(file.path(revdep_check_path_curr, "old"))
  revdep_check_path_curr_new <- check_and_create_dir(file.path(revdep_check_path_curr, "new"))

  temp <- download.packages(revdep, destdir = revdep_check_path_curr, type = "source")
  tarball <- temp[1,2]

  withr::with_envvar(
    revdepcheck:::check_env_vars(check_version = FALSE, force_suggests = TRUE),
    rcmd_output_old[[i]] <- rcmdcheck::rcmdcheck(
      path = tarball,
      libpath = c(revdep_library_path_old, .libPaths()),
      check_dir = revdep_check_path_curr_old
    )
  )

  withr::with_envvar(
    revdepcheck:::check_env_vars(check_version = FALSE, force_suggests = TRUE),
    rcmd_output_new[[i]] <- rcmdcheck::rcmdcheck(
      path = tarball,
      libpath = c(revdep_library_path_new, .libPaths()),
      check_dir = revdep_check_path_curr_new
    )
  )
}

