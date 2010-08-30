require 'main'

module RightData
  def self.hello; "Hi!"; end
  def self.prune_report(master,prunable)
    tree = RightData::scan_for_prunable(master,prunable) 
    tree.report('rm -rf'); nil
  end

  def self.dup_report(prunable)
    RightData::scan_for_dup(prunable)
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
