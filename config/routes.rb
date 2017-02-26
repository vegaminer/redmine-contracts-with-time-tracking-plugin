# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
#

match 'contracts/all'                                       => 'contracts#all',     :via => :get
match 'contracts/:id'                                       => 'contracts#destroy', :via => :delete
match 'contracts/:id/edit'                                  => 'contracts#edit',    :via => :get
match 'projects/:project_id/contracts'                      => 'contracts#index',   :via => :get
match 'projects/:project_id/contracts/default'              => 'contracts#default', :via => :get
match 'projects/:project_id/contracts/new'                  => 'contracts#new',     :via => :get
match 'projects/:project_id/contracts/:id/edit'             => 'contracts#edit',    :via => :get
match 'projects/:project_id/contracts/:id'                  => 'contracts#show',    :via => :get
match 'projects/:project_id/contracts'                      => 'contracts#create',  :via => :post
match 'projects/:project_id/contracts/:id'                  => 'contracts#update',  :via => :put
match 'projects/:project_id/contracts/:id'                  => 'contracts#destroy', :via => :delete
match 'projects/:project_id/contracts/:id/lock'          	=> 'contracts#lock', :via => :put
match 'projects/:project_id/contracts/:id/add_time_entries' => 'contracts#add_time_entries', :via => :get
match 'projects/:project_id/contracts/:id/assoc_time_entries_with_contract' => 
        'contracts#assoc_time_entries_with_contract', 
        :via => :put

# Expenses
match 'projects/:project_id/contracts/expenses/new'                   => 'contracts_expenses#new',   :via => :get
match 'projects/:project_id/contracts/expenses/:id/edit'              => 'contracts_expenses#edit',   :via => :get
match 'projects/:project_id/contracts/expenses/create'                => 'contracts_expenses#create',   :via => :post
match 'projects/:project_id/contracts/expenses/update/:id'            => 'contracts_expenses#update',   :via => :put
match 'projects/:project_id/contracts/expenses/destroy/:id'           => 'contracts_expenses#destroy',   :via => :delete

# Invoices
match 'projects/:project_id/contracts/invoices/new'                   => 'contracts_invoices#new',   :via => :get
match 'projects/:project_id/contracts/invoices/:id/edit'              => 'contracts_invoices#edit',   :via => :get
match 'projects/:project_id/contracts/invoices/create'                => 'contracts_invoices#create',   :via => :post
match 'projects/:project_id/contracts/invoices/update/:id'            => 'contracts_invoices#update',   :via => :put
match 'projects/:project_id/contracts/invoices/destroy/:id'           => 'contracts_invoices#destroy',   :via => :delete

match 'projects/:project_id/contracts/invoices/context_menu', :to => 'contracts_invoices#context_menu', :as => :contracts_invoices_context_menu_path, :via => [:get, :post]
