require 'sinatra'
require 'json'
require 'sinatra/activerecord'
require 'action_mailer'

require './config/initializers/mailjet.rb'
require './config/initializers/actionmailer.rb'
require './config/initializers/carrierwave.rb'

require './helpers/models.rb'
require './uploaders/fichier_uploader.rb'
require './helpers/s3.rb'

configure :staging, :production do
  require 'rack/ssl-enforcer'
  use Rack::SslEnforcer
end

set :database_file, "config/database.yml"

set :session_secret, ENV['SESSION_SECRET']
use Rack::Session::Cookie, :key => 'dossiersco', :path => '/', :secret => ENV['SESSION_SECRET'], :expire_after => 604800

require_relative 'helpers/formulaire'
require_relative 'helpers/init'
require_relative 'helpers/mot_de_passe'

identite_resp_legal = ["lien_de_parente", "prenom", "nom", "adresse", "code_postal", "ville", "tel_principal",
											 "tel_secondaire", "email", "situation_emploi", "profession", "enfants_a_charge",
                       "enfants_a_charge_secondaire", "communique_info_parents_eleves", "lien_avec_eleve"]

code_situation = {'0': '', '1': 'occupe un emploi', '2': 'Au chômage', '3': 'Pré retraité, retraité ou retiré',
  '4': 'Personne sans activité professionnelle'}

code_profession = {'0': '', '10': 'agriculteur exploitant', '21': 'artisan', '22': 'commerçant et assimilé',
  '23': "chef d'entreprise de 10 salariés et+", '31': 'profession libérale', '33': 'cadre de la fonction publique',
  '34': 'professeur, profession scientifique', '35': "profession de l'information, des arts et des spectacles",
  '37': "cadre administratif, commercial d'entreprise", '38': "ingénieur, cadre technique d'entreprise",
  '42': "instituteur et assimilé", '43': "profession intermédiaire de la santé et du travail social",
  '44': 'Clergé, religieux', '45': "Profession intermédiaire administrative de la fonction publique",
  '46': "Profession intermédiaire administrative et commerciale des entreprises", '47': "Technicien",
  '48': "Contremaître, agent de maîtrise", '52': "Employé civil et agent de service de la fonction publique",
  '53': 'Policier, militaire', '54': "Employé administratif d'entreprise", '55': "Employé de commerce",
  '56': "Personnel service direct aux particuliers", '61': "Ouvrier qualifié", '66': "Ouvrier non qualifié",
  '69': "Ouvrier agricole", '71': "Retraité agriculteur exploitant",
  '72': "Retraité artisan, commerçant, chef d'entreprise", '73': "Retraité cadre, profession interm édiaire",
  '76': "Retraité employé, ouvrier", '82': "Personne sans activité professionnelle" }

configure :test, :development, :staging do
  get '/init' do
    init
    redirect '/'
  end
end

before '/unepagequileveuneexception' do
  raise ArgumentError
end

before '/*' do
  agent_before = agent
  eleve_before = eleve
  identification = request.path_info == "/identification"
  home = request.path_info == "/"
  piece_jointe = request.path_info.start_with?("/piece")
  agent = request.path_info.start_with?("/agent")
  api = request.path_info.start_with?("/api")
  init = request.path_info.start_with?("/init")
  pass if home || identification || piece_jointe || agent || api || init
  pass if eleve_before.present?
  pass if agent_before.present?
  return if home
  session[:message_erreur] = "Vous avez été déconnecté par mesure de sécurité. Merci de vous identifier avant de continuer."
  redirect '/'
end

get '/' do
	erb :'#_identification'
end

post '/identification' do
	if params[:identifiant].empty? || params[:date_naiss].empty?
		session[:message_erreur] = "Veuillez renseigner l'identifiant et la date de naissance de l'élève."
		redirect '/'
	end
	dossier_eleve = get_dossier_eleve params[:identifiant]
  date_saisie = normalise(params[:date_naiss]) || 'pas-de-date'
	if dossier_eleve.present? && (dossier_eleve.eleve.date_naiss == date_saisie)
    if dossier_eleve.etat == 'pas connecté'
      dossier_eleve.update(etat: 'connecté')
    end
		session[:identifiant] = params[:identifiant]
		session[:demarche] = dossier_eleve.demarche
		redirect "/#{dossier_eleve.etape}"
	else
    # Emettre un message générique quelle que soit l'erreur pour éviter
    # de "fuiter" de l'information sur l'existence ou non des identifiants
    session[:message_erreur] = "Nous n'avons pas reconnu ces identifiants, merci de les vérifier."
		redirect '/'
	end
end

get '/accueil' do
	erb :'0_accueil', locals: { dossier_eleve: eleve.dossier_eleve }
end

get '/eleve' do
  options_du_niveau = eleve.montee.present? ? eleve.montee.demandabilite.collect(&:option) : []
  erb :'1_eleve', locals: { eleve: eleve, options_du_niveau: options_du_niveau }
end

post '/eleve' do
  eleve_a_modifier = eleve
  identite_eleve = ['prenom', 'prenom_2', 'prenom_3', 'nom', 'sexe', 'ville_naiss', 'pays_naiss', 'nationalite', 'classe_ant', 'ets_ant']
  identite_eleve.each do |info|
	 eleve_a_modifier[info] = params[info] if params.has_key?(info)
  end

  # Pour chaque option de l'élève, vérifier si elle doit être abandonnée
  options = eleve.montee.present? ? eleve.montee.abandonnabilite.collect(&:option) : []
  options.each do |option|
    if params["#{option.nom}_present"]
      abandon = Abandon.find_or_initialize_by(eleve: eleve, option: option)
      eleve_a_modifier.abandon.delete abandon if params[option.nom] == 'true'
      eleve_a_modifier.abandon << abandon if params[option.nom].nil?
    end
  end

  # Pour chacune des options vérifier si elle est choisie directement
  options = eleve.montee.present? ? eleve.montee.demandabilite.collect(&:option) : []
  options.each do |option|
    if params["#{option.nom}_present"]
      demande = Demande.find_or_initialize_by(eleve: eleve, option: option)
      eleve_a_modifier.demande.delete demande if params[option.nom].nil?
      eleve_a_modifier.demande << demande if params[option.nom] == 'true'
    end
  end

  # Ensuite on va itérer sur les groupes
  options.collect(&:groupe).uniq.each do |groupe|
    if params[groupe].present?
      # On découvre l'option retenue
      option_choisie = options.find {|option| option.nom == params[groupe]}
      demande = Demande.find_or_initialize_by(eleve: eleve, option: option_choisie)
      # On supprime les autres (choix mutuellement exclusif)
      eleve_a_modifier.demande.each do |demande_presente|
        eleve_a_modifier.demande.delete demande_presente if demande_presente.option.groupe == groupe
      end
      # On garde celle retenue
      eleve_a_modifier.demande << demande
    end
  end
  eleve_a_modifier.save!

  sauve_et_redirect eleve.dossier_eleve, 'famille'
end

get '/famille' do
	dossier_eleve = eleve.dossier_eleve
	resp_legal1 = RespLegal.find_by(dossier_eleve_id: dossier_eleve.id, priorite: 1)
	resp_legal2 = RespLegal.find_by(dossier_eleve_id: dossier_eleve.id, priorite: 2)
	contact_urgence = ContactUrgence.find_by(dossier_eleve_id: dossier_eleve.id)

	identite_resp_legal.each do |i|
		params["#{i}_rl1"] = resp_legal1[i] if !resp_legal1.nil? && !resp_legal1[i].nil?
		params["#{i}_rl2"] = resp_legal2[i] if !resp_legal2.nil? && !resp_legal2[i].nil?
		params["#{i}_urg"] = contact_urgence[i] if !contact_urgence.nil? && !contact_urgence[i].nil?
	end

  resp_legal_2 = dossier_eleve.resp_legal.select {|resp_legal| resp_legal.priorite == 2}.first

  erb :'3_famille', locals: {resp_legal_2: resp_legal_2, contact_urgence: dossier_eleve.contact_urgence,
    code_profession: code_profession, code_situation: code_situation}
end

post '/famille' do
  dossier_eleve = eleve.dossier_eleve
	resp_legal1 = RespLegal.find_by(dossier_eleve_id: dossier_eleve.id, priorite: 1) || RespLegal.new(priorite: 1, dossier_eleve_id: dossier_eleve.id)
	resp_legal2 = RespLegal.find_by(dossier_eleve_id: dossier_eleve.id, priorite: 2) || RespLegal.new(priorite: 2, dossier_eleve_id: dossier_eleve.id)
	contact_urgence = ContactUrgence.find_by(dossier_eleve_id: dossier_eleve.id) || ContactUrgence.new(dossier_eleve_id: dossier_eleve.id)

  resp_legal1.changement_adresse = true if resp_legal1.adresse.to_s.upcase != params['adresse_rl1'].to_s.upcase
  resp_legal2.changement_adresse = true if resp_legal2.adresse.to_s.upcase != params['adresse_rl2'].to_s.upcase

	identite_resp_legal.each do |i|
		resp_legal1[i] = params["#{i}_rl1"] if params.has_key?("#{i}_rl1")
		resp_legal2[i] = params["#{i}_rl2"] if params.has_key?("#{i}_rl2")
		contact_urgence[i] = params["#{i}_urg"] if params.has_key?("#{i}_urg")
	end

	resp_legal1.save!
	resp_legal2.save!
	contact_urgence.save!
	sauve_et_redirect dossier_eleve, 'administration'
end

get '/administration' do
	erb :'4_administration', locals: {dossier_eleve: eleve.dossier_eleve}
end

post '/administration' do
	dossier_eleve = eleve.dossier_eleve
	dossier_eleve.demi_pensionnaire = params['demi_pensionnaire']
	dossier_eleve.autorise_sortie = params['autorise_sortie']
	dossier_eleve.renseignements_medicaux = params['renseignements_medicaux']
  dossier_eleve.check_paiement_cantine = params['check_paiement_cantine']
	dossier_eleve.save!
	sauve_et_redirect dossier_eleve, 'pieces_a_joindre'
end

get '/piece/:dossier_eleve/:code_piece/:s3_key' do
  dossier_eleve = get_dossier_eleve params[:dossier_eleve]

  # Vérifier les droits d'accès
  famille_autorisé = params[:dossier_eleve] == session[:identifiant]

  agent = Agent.find_by(identifiant: session[:identifiant])
  agent_autorisé = agent.present? and (dossier_eleve.etablissement == agent.etablissement)

  usager_autorisé = famille_autorisé || agent_autorisé

  objet_demandé = params[:s3_key]
  objet_présent = PieceJointe.find_by(dossier_eleve_id: dossier_eleve.id, clef: params[:s3_key])
  clef_objet_présent = objet_présent.clef if objet_présent.present?
  objet_conforme = objet_demandé == clef_objet_présent

  if usager_autorisé and objet_conforme
    objet_normalise = objet_demandé.downcase
    fichier = get_fichier_s3(objet_normalise)
    if objet_normalise.end_with? 'pdf'
      content_type 'application/pdf'
    elsif objet_normalise.end_with? 'jpg' or objet_normalise.end_with? 'jpeg'
      content_type 'image/jpeg'
    elsif objet_normalise.end_with? 'png'
      content_type 'image/png'
    end
    open fichier.url(Time.now.to_i + 30)
  else
    redirect '/'
  end
end

get '/pieces_a_joindre' do
	erb :'5_pieces_a_joindre', locals: {dossier_eleve: eleve.dossier_eleve}
end

post '/pieces_a_joindre' do
  dossier_eleve = eleve.dossier_eleve
  pieces_attendues = dossier_eleve.etablissement.piece_attendue
  pieces_obligatoires = false
  pieces_attendues.each do |piece|
  piece_jointe = piece.piece_jointe
    if !piece_jointe.present? && piece.obligatoire
      pieces_obligatoires = true
    end
  end
  if pieces_obligatoires
    erb :'5_pieces_a_joindre', locals: {dossier_eleve: dossier_eleve, message: 'Veuillez télécharger les pièces obligatoires'}
  else
    redirect '/validation'
  end
end

post '/enregistre_piece_jointe' do
  dossier_eleve = eleve.dossier_eleve
  params.each do |code, piece|
    if params[code].present? and params[code]["tempfile"].present?
      file = File.open(params[code]["tempfile"])
      uploader = FichierUploader.new
      uploader.store!(file)
      nom_du_fichier = File.basename(file.path)
      piece_attendue = PieceAttendue.find_by(code: code, etablissement_id: dossier_eleve.etablissement_id)
      piece_jointe = PieceJointe.find_by(piece_attendue_id: piece_attendue.id, dossier_eleve_id: dossier_eleve.id)
      if piece_jointe.present?
        piece_jointe.update(etat: 'soumis', clef: nom_du_fichier)
      else
        piece_jointe = PieceJointe.create!(etat: 'soumis', clef: nom_du_fichier, piece_attendue_id: piece_attendue.id, dossier_eleve_id: dossier_eleve.id)
      end
    end
  end
  redirect '/pieces_a_joindre'
end

post '/pieces_a_joindre' do
  redirect '/validation'
end

get '/validation' do
	erb :'6_validation', locals: { eleve: eleve, dossier_eleve: eleve.dossier_eleve }
end

post '/validation' do
  dossier_eleve = eleve.dossier_eleve
  dossier_eleve.signature = params[:signature]
  dossier_eleve.date_signature = Time.now
  dossier_eleve.save
  redirect '/confirmation'
end

get '/confirmation' do
  dossier_eleve = eleve.dossier_eleve
  if dossier_eleve.etat != 'validé'
    dossier_eleve.update(etat: 'en attente de validation')
  end
	erb :'7_confirmation', locals: { eleve: eleve, dossier_eleve: dossier_eleve }
end

post '/satisfaction' do
  dossier_eleve = eleve.dossier_eleve
  dossier_eleve.satisfaction = params[:note]
  dossier_eleve.save!
end

post '/commentaire' do
  dossier_eleve = eleve.dossier_eleve
  dossier_eleve.commentaire = params[:commentaire]
  dossier_eleve.save!
  redirect '/confirmation'
end

post '/envoyer_email_confirmation' do
  dossier_eleve = get_dossier_eleve session[:identifiant]
  mail = AgentMailer.envoyer_mail_confirmation(dossier_eleve.eleve)
  mail.deliver_now
end

not_found do
  erb :not_found
end

error do
  erb :error
end

def sauve_et_redirect dossier_eleve, etape
  dossier_eleve.etape = etape
  dossier_eleve.save!
  redirect "/#{etape}"
end

