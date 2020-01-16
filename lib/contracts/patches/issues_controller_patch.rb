require_dependency 'issues_controller'

module Contracts

	module IssuesControllerPatch
		def self.included(base)
	  		base.class_eval do
	  			#after_filter :check_flash_messages, :only => [:update]
				after_action :check_flash_messages, :only => [:update]

	  			def check_flash_messages
					return if @time_entry.nil?
	  				if @time_entry.flash_only_one_time_entry
	  					flash[:contract] = l(:text_one_time_entry_saved)
	  				elsif @time_entry.flash_time_entry_success
							flash[:contract] = l(:text_split_time_entry_saved)
						elsif @time_entry.flash_time_entry_to_smart_contract_success
							if User.current.allowed_to?(:view_hourly_rate, @time_entry.project)
								contract = Contract.contract_for_time_entry(@time_entry)
								if (contract)
									notice = l(:text_time_entry_added_to_contract, :contract => view_context.link_to(contract.getDisplayTitle, url_for({ :controller => 'contracts', :action => 'show', :project_id => contract.project.identifier, :id => contract.id })))
									if flash[:notice].nil?
										flash[:contract] = notice
									else
										flash[:notice] += '  ' + notice
									end
								else
									flash[:contract_warning] = l(:text_time_entry_not_added_to_contract)
								end
							end
				    end
	  			end
	  		end
	 	end
	end
end
