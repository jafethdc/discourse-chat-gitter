require_dependency 'admin_constraint'

DiscourseGitter::Engine.routes.draw do
  post 'filter_rules' => 'filter_rules#create', constraints: AdminConstraint.new
  delete 'filter_rules' => 'filter_rules#delete', constraints: AdminConstraint.new

  get 'integrations' => 'integrations#index', constraints: AdminConstraint.new
  post 'integrations' => 'integrations#create', constraints: AdminConstraint.new
  delete 'integrations' => 'integrations#delete', constraints: AdminConstraint.new
  put 'test_notification' => 'integrations#test_notification', constraints: AdminConstraint.new
end
