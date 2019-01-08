ENV['RACK_ENV'] = 'test'

require 'nokogiri'
require 'test/unit'
require 'rack/test'
require 'tempfile'

require_relative '../helpers/singulier_francais'

require_relative '../dossiersco_web'
require_relative '../dossiersco_agent'

class EleveFormTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include MotDePasse

  def app
    Sinatra::Application
  end

  def setup
    ActiveRecord::Schema.verbose = false
    require_relative "../db/schema.rb"
    init
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries = []
  end
  def test_affichage_preview_jpg_famille
    eleve = Eleve.find_by(identifiant: 6)
    piece_attendue = PieceAttendue.find_by(code: 'assurance_scolaire',
      etablissement_id: eleve.dossier_eleve.etablissement.id)
    piece_jointe = PieceJointe.create(clef: 'assurance_photo.jpg', dossier_eleve_id: eleve.dossier_eleve.id,
      piece_attendue_id: piece_attendue.id)
    post '/identification', identifiant: '6', annee: '1970', mois: '01', jour: '01'
    get '/pieces_a_joindre'
    doc = Nokogiri::HTML(last_response.body)
    documents_route = FichierUploader::route_lecture '6', 'assurance_scolaire'
    expected_url = documents_route+"/assurance_photo.jpg"
    assert_equal "background-image: url('#{expected_url}'); height: 200px; max-width: 350px;",
                 doc.css("#image_assurance_scolaire").attr("style").text
    assert doc.css('#image_assurance_scolaire').attr("class").text.split.include?("lien-piece-jointe")
    assert_equal "modal", doc.css('#image_assurance_scolaire').attr("data-toggle").text
    assert_equal "#modal-pieces-jointes", doc.css('#image_assurance_scolaire').attr("data-target").text
    assert_equal expected_url, doc.css('#image_assurance_scolaire').attr("data-url").text
  end

  def test_affichage_preview_pdf_famille
    eleve = Eleve.find_by(identifiant: 6)
    piece_attendue = PieceAttendue.find_by(code: 'assurance_scolaire',
      etablissement_id: eleve.dossier_eleve.etablissement.id)
    piece_jointe = PieceJointe.create(clef: 'assurance_scannee.pdf', dossier_eleve_id: eleve.dossier_eleve.id,
      piece_attendue_id: piece_attendue.id)
    post '/identification', identifiant: '6', annee: '1970', mois: '01', jour: '01'
    get '/pieces_a_joindre'
    doc = Nokogiri::HTML(last_response.body)
    documents_route = FichierUploader::route_lecture '6', 'assurance_scolaire'
    expected_url = documents_route+"/assurance_scannee.pdf"
    assert_equal "background-image: url('/images/document-pdf.png'); height: 200px; max-width: 350px;",
                 doc.css("#image_assurance_scolaire").attr("style").text
    assert doc.css('#image_assurance_scolaire').attr("class").text.split.include?("lien-piece-jointe")
    assert_equal "modal", doc.css('#image_assurance_scolaire').attr("data-toggle").text
    assert_equal "#modal-pieces-jointes", doc.css('#image_assurance_scolaire').attr("data-target").text
    assert_equal expected_url, doc.css('#image_assurance_scolaire').attr("data-url").text
  end

  def test_envoyer_un_mail_quand_la_demande_dinscription_est_valide
    post '/identification', identifiant: '4', annee: '1970', mois: '01', jour: '01'
    post '/validation'

    mail = ActionMailer::Base.deliveries.last
    assert_equal 'contact@dossiersco.beta.gouv.fr', mail['from'].to_s
    assert mail['to'].addresses.collect(&:to_s).include? 'test@test.com'
    assert mail['to'].addresses.collect(&:to_s).include? 'test2@test.com'
    assert mail['to'].addresses.collect(&:to_s).include? 'contact@dossiersco.beta.gouv.fr'
    assert_equal "Réinscription de votre enfant au collège", mail['subject'].to_s
    part = mail.html_part || mail.text_part || mail
    assert part.body.decoded.include? "réinscription de votre enfant Pierre Blayo"
    assert part.body.decoded.include? "Tillion"
  end

  def test_une_personne_non_identifiée_ne_peut_accéder_à_pièces
    get "/piece/6/assurance_scolaire/nimportequoi"

    assert_equal 302, response.status
  end

  def test_famille_peut_accéder_à_une_pièce_de_son_dossier
    post '/identification', identifiant: '6', annee: '1970', mois: '01', jour: '01'

    piece_a_joindre = Tempfile.new('fichier_temporaire')

    post '/enregistre_piece_jointe', assurance_scolaire: {"tempfile": piece_a_joindre.path}

    get "/piece/6/assurance_scolaire/#{File.basename(piece_a_joindre.path)}"

    assert_equal 200, response.status
  end

  def assert_file(chemin_du_fichier)
    assert File.file? chemin_du_fichier
    File.delete(chemin_du_fichier)
  end

  def test_une_option_facultative_demandee
    post '/identification', identifiant: '6', annee: '1970', mois: '01', jour: '01'
    eleve = Eleve.find_by(identifiant: '6')
    montee = Montee.create

    grec = Option.create(nom: 'grec', groupe: 'LCA', modalite: 'facultative')
    grec_d = Demandabilite.create montee_id: montee.id, option_id: grec.id
    montee.demandabilite << grec_d
    eleve.montee = montee
    eleve.demande << Demande.create(eleve: eleve, option: grec)
    eleve.save

    resultat = eleve.genere_demandes_possibles

    assert_equal 'LCA', resultat[0][:label]
    assert_equal 'check', resultat[0][:type]
    assert_equal true, resultat[0][:condition]
    assert resultat[0][:name].include?('grec')

    post '/eleve', grec_present: 'true', grec: 'true'
    eleve = Eleve.find_by(identifiant: '6')
    assert_equal 1, eleve.demande.count
    assert_equal 'grec', eleve.demande.first.option.nom

    resultat = eleve.genere_demandes_possibles
    assert_equal true, resultat[0][:condition]

    post '/eleve', grec_present: 'true'
    eleve = Eleve.find_by(identifiant: '6')
    assert_equal 0, eleve.demande.count

    resultat = eleve.genere_demandes_possibles
    assert_equal false, resultat[0][:condition]
  end

  def test_affichage_obligatoire_sans_choix
    post '/identification', identifiant: '5', annee: '1970', mois: '01', jour: '01'
    eleve = Eleve.find_by(identifiant: '5')

    get '/eleve'

    doc = Nokogiri::HTML(response.parsed_body)
    assert_equal "latin", doc.css("body > main > div.col-sm-12 > form > div:nth-child(13) > div").text.strip
    assert_equal "grec", doc.css("body > main > div.col-sm-12 > form > div:nth-child(14) > div").text.strip
  end

  def test_afficher_option_a_choisir_que_quand_choix_possible
    montee = Montee.create
    e = Eleve.create!(identifiant: 'XXX', date_naiss: '1970-01-01', montee: montee)
    dossier_eleve = DossierEleve.create!(eleve_id: e.id, etablissement_id: Etablissement.first.id)
    post '/identification', identifiant: 'XXX', annee: '1970', mois: '01', jour: '01'

    get '/eleve'

    assert ! response.parsed_body.include?("Options choisies précédemment")
    assert ! response.parsed_body.include?("Vos options pour l'année prochaine")
  end

  def test_affiche_option_obligatoire_nouvelle_pour_cette_montee
    montee = Montee.create
    eleve = Eleve.create!(identifiant: 'XXX', date_naiss: '1970-01-01', montee: montee)
    dossier_eleve = DossierEleve.create!(eleve_id: eleve.id, etablissement_id: Etablissement.first.id)

    grec_obligatoire = Option.create(nom: 'grec', groupe: 'LCA', modalite: 'obligatoire')
    grec_obligatoire_d = Demandabilite.create montee_id: montee.id, option_id: grec_obligatoire.id
    montee.demandabilite << grec_obligatoire_d

    resultat = eleve.genere_demandes_possibles

    assert_equal "LCA", resultat[0][:label]
    assert_equal 'grec', resultat[0][:name]
    assert_equal 'hidden', resultat[0][:type]
  end

  def test_affiche_option_abandonnable
    eleve = Eleve.create!(identifiant: 'XXX', date_naiss: '1970-01-01')
    dossier_eleve = DossierEleve.create!(eleve_id: eleve.id, etablissement_id: Etablissement.first.id)
    montee = Montee.create
    latin = Option.create(nom: 'latin', groupe: 'LCA', modalite: 'facultative')
    latin_d = Abandonnabilite.create montee_id: montee.id, option_id: latin.id
    eleve.option << latin
    montee.abandonnabilite << latin_d
    eleve.update(montee: montee)

    post '/identification', identifiant: 'XXX', annee: '1970', mois: '01', jour: '01'
    get '/eleve'

    resultat = eleve.genere_abandons_possibles

    assert_equal "Poursuivre l'option", resultat[0][:label]
    assert_equal 'latin', resultat[0][:name]
    assert_equal 'check', resultat[0][:type]

    # Si la checkbox n'est pas cochée le navigateur ne transmet pas la valeur
    post '/eleve', latin_present: true
    eleve = Eleve.find_by(identifiant: 'XXX')
    assert_equal 1, eleve.abandon.count
    assert_equal 'latin', eleve.abandon.first.option.nom

    resultat = eleve.genere_abandons_possibles
    assert_equal "Poursuivre l'option", resultat[0][:label]
    assert_equal false, resultat[0][:condition]

    post '/eleve', latin_present: true, latin: true
    eleve = Eleve.find_by(identifiant: 'XXX')
    assert_equal 0, eleve.abandon.count

    resultat = eleve.genere_abandons_possibles
    assert_equal "Poursuivre l'option", resultat[0][:label]
    assert_equal true, resultat[0][:condition]
  end

  def test_affiche_404
    # Sans identification, on est redirigé vers l'identification
    get '/unepagequinexistepas'
    assert last_response.redirect?

    post '/identification', identifiant: '5', annee: '1970', mois: '01', jour: '01'
    get '/unepagequinexistepas'
    assert last_response.body.include? "une page qui n'existe pas"
  end

  def test_erreur_interne
    Sinatra::Application::set :environment, 'production'
    get '/unepagequileveuneexception'
    assert last_response.body.include? "une erreur technique"
    Sinatra::Application::set :environment, 'development'
  end

  def test_affiche_pas_resp_legal_2_si_absent_de_siecle
    e = Eleve.create! identifiant: 'XXX', date_naiss: '1915-12-19'
    dossier_eleve = DossierEleve.create! eleve_id: e.id, etablissement_id: Etablissement.first
    RespLegal.create! dossier_eleve_id: dossier_eleve.id, email: 'test@test.com', priorite: 1

    post '/identification', identifiant: 'XXX', annee: '1915', mois: '12', jour: '19'
    get '/famille'

    doc = Nokogiri::HTML(last_response.body)
    assert_nil doc.css("div#resp_legal_2").first
  end

  # le masquage du formulaire de contact se fait en javascript
  def test_html_du_contact_present_dans_page_quand_pas_encore_de_contact
    e = Eleve.create! identifiant: 'XXX', date_naiss: '1915-12-19'
    dossier_eleve = DossierEleve.create! eleve_id: e.id, etablissement_id: Etablissement.first
    RespLegal.create! dossier_eleve_id: dossier_eleve.id, email: 'test@test.com', priorite: 1

    post '/identification', identifiant: 'XXX', annee: '1915', mois: '12', jour: '19'
    get '/famille'

    doc = Nokogiri::HTML(last_response.body)
    assert_not_nil doc.css("input#tel_principal_urg").first
  end

  def test_ramene_a_la_dernire_etape_visitee_plutot_que_l_etape_la_plus_avancee
    post '/identification', identifiant: '4', annee: '1970', mois: '01', jour: '01'
    post '/famille'
    get '/eleve'
    post '/deconnexion'
    post '/identification', identifiant: '4', annee: '1970', mois: '01', jour: '01'
    follow_redirect!
    assert last_response.body.include? "Identité de l'élève"
  end

  def test_ramene_a_l_etape_confirmation_pour_la_satisfaction
    post '/identification', identifiant: '4', annee: '1970', mois: '01', jour: '01'
    get '/confirmation'
    post '/satisfaction'
    post '/deconnexion'
    post '/identification', identifiant: '4', annee: '1970', mois: '01', jour: '01'
    follow_redirect!
    assert last_response.body.include? "Vous recevrez prochainement un courriel de confirmation"
  end

end
