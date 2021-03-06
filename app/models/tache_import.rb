class TacheImport < ActiveRecord::Base
  belongs_to :etablissement

  has_one_attached :fichier

  def traiter
    self.update(statut: 'en_cours')
    statistiques = import_xls File.new(self.fichier.service_url), self.etablissement_id, self.nom_a_importer, self.prenom_a_importer
    self.update(
        statut: 'terminée',
        message: "#{statistiques[:eleves]} élèves importés : "+
            "#{statistiques[:portable]}% de téléphones portables et "+
            "#{statistiques[:email]}% d'emails")
  end
end
