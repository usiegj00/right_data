require 'main'

module RightData
  def self.hello; "Hi!"; end

  # Run this in a directory (prunable) that is suspected of containing duplicate files that
  # already exist in master. E.g. check a discovered backup drive and whether anything on it is valid
  def self.prune_report(master,prunable)
    tree = RightData::scan_for_prunable(master,prunable) 
    tree.report('rm -rf'); nil
  end

  # Run this in a directory that is suspected of containing self-duplicate files.
  # Compare to: fdupes -r -n prunable
  def self.dup_report(prunable)
    RightData::scan_for_dup(prunable)
  end

  # Run this on a directory that is suspected of containing unchecked in GIT or SVN repos.
  # Get back a list of all repos, versions and whether any files are unchecked in.
  def self.repo_report(search_dir)
    tree = RightData::scan_for_repos(search_dir) 
  end
end
# Usage:
# Prune any files from prunable that are already in master:
# echo "gem 'right_data'; require 'right_data'; prune_report(master,prunable)" | ruby -rrubygems > rm_report
# Inspect / add #!/bin/sh
# chmod +x rm_report
# ./rm_report
#
# Find duplicates:
# echo "gem 'right_data'; require 'right_data'; dup_report(runable)" | ruby -rrubygems > rm_report
