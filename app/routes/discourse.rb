
Discourse::Application.routes.append do
  mount ::DiscourseGitter::Engine, at: '/gitter'
  get '/admin/plugins/gitter' => 'admin/plugins#index', constraints: StaffConstraint.new
end
