require 'uri'
require 'net/http'
require 'net/https'
require 'json'
require 'tilt/erb'

class DossierEleve < ActiveRecord::Base
  belongs_to :eleve
  belongs_to :etablissement
  has_many :resp_legal
  has_one :contact_urgence
  has_many :piece_jointe
  has_many :message

  def resp_legal_1
    self.resp_legal.find {|r| r.priorite == 1}
  end

  def resp_legal_2
    self.resp_legal.find {|r| r.priorite == 2}
  end

  def allocataire
    enfants = self.resp_legal.first.enfants_a_charge || 0
    enfants > 1
  end

  DEFAULT_TEMPLATE = "<%= eleve.dossier_eleve.etablissement.nom %>: attention, derniers jours pour réinscrire votre enfant <%= eleve.prenom %> sur https://dossiersco.fr avec vos identifiants: <%= eleve.identifiant %> et la date de naissance de l'enfant."

  def relance_sms template = DEFAULT_TEMPLATE
    # Construction du message
    template = Tilt['erb'].new { template }
    text = template.render(nil,eleve: eleve)

    Message.create(categorie:"sms", contenu: text, etat: "en attente", dossier_eleve: self)
  end

  def portable_present
    portable_rl1.present? || portable_rl2.present?
  end

  def portable_rl1
    portable resp_legal_1
  end

  def portable_rl2
    portable resp_legal_2 if resp_legal_2
  end

  def portable rl
    secondaire = rl.tel_secondaire
    return secondaire unless (secondaire.blank? || secondaire.start_with?("01"))
    return rl.tel_principal
  end

  def date_signature_gmt_plus_2
    return "" unless self.date_signature
    self.date_signature.localtime("+02:00").strftime "%d/%m à %H:%M"
  end

  def valide
    update(etat: 'validé')
    mail = AgentMailer.mail_validation_inscription(eleve)
    mail.deliver_now
  end

end