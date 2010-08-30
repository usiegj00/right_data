require 'main'

module RightData
  def self.hello; "Hi!"; end
  def prune_report(master,prunable)
    tree = RightData::scan_for_prunable(master,prunable) 
    tree.report('rm -rf'); nil
  end
end
# Usage:
# echo "gem 'right_data'; require 'right_data'; prune_report(master,prunable)" | ruby -rrubygems
