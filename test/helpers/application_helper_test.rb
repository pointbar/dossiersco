require 'test_helper'

class ApplicationHelperTest < ActionDispatch::IntegrationTest
  include ApplicationHelper

  test "super_admin? fonctionne, même sans avoir créé la variable d'environnement SUPER_ADMIN" do
    ENV['SUPER_ADMIN'] = nil
    assert ! super_admin?('Henri')
  end

  test "super_admin? fonctionne, avec nil en paramètre" do
    ENV['SUPER_ADMIN'] = "Henri"
    assert ! super_admin?(nil)
  end

  test "super_admin? renvoie true quand l'identifiant est dans la variable d'environnement SUPER_ADMIN" do
    ENV['SUPER_ADMIN'] = "Henri"
    assert super_admin?('Henri')
  end

  test "super_admin? renvoie true peut importe la casse quand l'identifiant est dans la variable d'environnement SUPER_ADMIN" do
    ENV['SUPER_ADMIN'] = "henri"
    assert super_admin?('Henri')
  end

  test "super_admin? renvoie false quand l'identifiant n'est dans la variable d'environnement SUPER_ADMIN" do
    ENV['SUPER_ADMIN'] = "Henri"
    assert ! super_admin?('Pascal')
  end

end
