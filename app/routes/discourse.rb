
Discourse::Application.routes.append do
  mount ::Gitter::Engine, at: '/gitter'
  get '/admin/plugins/gitter' => 'admin/plugins#index', constraints: StaffConstraint.new
end
