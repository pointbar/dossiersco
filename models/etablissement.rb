class Etablissement < ActiveRecord::Base
  has_many :dossier_eleve
  has_many :agent
  has_many :option
end
