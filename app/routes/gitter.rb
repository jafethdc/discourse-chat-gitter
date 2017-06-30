require_dependency 'admin_constraint'

Gitter::Engine.routes.draw do
  post 'filter_rules' => 'filter_rules#create', constraints: AdminConstraint.new
  delete 'filter_rules' => 'filter_rules#delete', constraints: AdminConstraint.new

  get 'integrations' => 'integrations#index', constraints: AdminConstraint.new
  post 'integrations' => 'integrations#create', constraints: AdminConstraint.new
end
