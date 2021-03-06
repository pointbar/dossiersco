require 'test_helper'
require 'fixtures'
init

class AccueilControllerTest < ActionDispatch::IntegrationTest
  def test_accueil
    get '/'
    assert response.parsed_body.include? 'Inscription'
  end

  def test_entree_succes_eleve_vierge
    e = Eleve.create! identifiant: 'XXX', date_naiss: '1915-12-19', nom: 'Piaf', prenom: 'Edit'
    DossierEleve.create! eleve_id: e.id, etablissement_id: Etablissement.first.id
    post '/identification', params: {identifiant: 'XXX ', annee: '1915', mois: '12', jour: '19'}
    follow_redirect!
    assert response.parsed_body.include? 'Pour réinscrire votre enfant'
  end

  def _test_normalise_INE
    # en attendant de place cette méthode en dehors du controller
    assert_equal "070803070AJ", normalise_alphanum(" %! 070803070aj _+ ")
  end

  def test_message_erreur_identification
    assert_equal 'Veuillez fournir identifiant et date de naissance', message_erreur_identification(nil, '14-05-2018')
    assert_equal 'Veuillez fournir identifiant et date de naissance', message_erreur_identification('', '14-05-2018')
    assert_equal 'Veuillez fournir identifiant et date de naissance', message_erreur_identification('XXX', nil)
    assert_equal 'Veuillez fournir identifiant et date de naissance', message_erreur_identification('XXX', '')
  end

  def test_entree_succes_eleve_1
    post '/identification', params: { identifiant: '1 ', annee: '1995', mois: '11', jour: '19'}
    follow_redirect!
    assert response.parsed_body.include? 'Pour réinscrire votre enfant'
  end


  def test_entree_mauvaise_date
    post '/identification', params: {identifiant: '3', annee: '1995', mois: '11', jour: '19'}
    follow_redirect!
    assert response.parsed_body.include? html_escape("Nous n'avons pas reconnu ces identifiants, merci de les vérifier.")
  end

  def test_entree_mauvais_identifiant_et_date
    post '/identification', params: {identifiant: 'toto', annee: '1998', mois: '11', jour: '19'}
    follow_redirect!
    assert response.parsed_body.include? html_escape("Nous n'avons pas reconnu ces identifiants, merci de les vérifier.")
  end

  def test_nom_college_accueil
    post '/identification', params: { identifiant: '1', annee: '1995', mois: '11', jour: '19' }
    follow_redirect!
    doc = Nokogiri::HTML(response.parsed_body)
    assert_equal 'College Jean-Francois Oeben', doc.xpath("//div//h1/text()").to_s
    assert_equal 'College Jean-Francois Oeben.', doc.xpath("//strong[@id='etablissement']/text()").to_s.strip
    assert_equal 'samedi 3 juin 2018', doc.xpath("//strong[@id='date-limite']/text()").to_s
  end

  def test_modification_lieu_naiss_eleve
    post '/identification', params: { identifiant: '2', annee: '1915', mois: '12', jour: '19'}
    post '/eleve', params: {ville_naiss: 'Beziers', prenom: 'Edith'}
    get '/eleve'
    assert response.parsed_body.include? 'Edith'
    assert response.parsed_body.include? 'Beziers'
  end

  def test_modifie_une_information_de_eleve_preserve_les_autres_informations
    post '/identification', params: { identifiant: '2', annee: '1915', mois: '12', jour: '19'}
    post '/eleve', params: {prenom: 'Edith'}
    get '/eleve'
    assert response.parsed_body.include? 'Piaf'
  end

  def test_affiche_2ème_et_3ème_prénoms_en_4ème_pour_brevet_des_collèges
    post '/identification', params: {identifiant: '4', annee: '1970', mois: '01', jour: '01'}
    get '/eleve'
    assert response.parsed_body.include? 'Deuxième prénom'
    assert response.parsed_body.include? 'Troisième prénom'
  end

  def test_n_affiche_pas_2ème_et_3ème_prénoms_en_5ème
    post '/identification', params: {identifiant: '5', annee: '1970', mois: '01', jour: '01'}
    get '/eleve'
    assert_no_match /Deuxième prénom/, response.parsed_body
    assert_no_match /Troisième prénom/, response.parsed_body
  end

  def test_n_affiche_pas_2ème_et_3ème_prénoms_en_6ème
    post '/identification', params: {identifiant: '6', annee: '1970', mois: '01', jour: '01'}
    get '/eleve'
    assert_no_match /Deuxième prénom/, response.parsed_body
    assert_no_match /Troisième prénom/, response.parsed_body
  end

  def test_affiche_2ème_et_3ème_prénoms_en_CM2
    post '/identification', params: {identifiant: '1', annee: '1995', mois: '11', jour: '19'}
    get '/eleve'
    assert response.parsed_body.include? 'Deuxième prénom'
    assert response.parsed_body.include? 'Troisième prénom'
  end

  def test_accueil_et_inscription
    post '/identification', params: {identifiant: '1', annee: '1995', mois: '11', jour: '19'}
    follow_redirect!
    assert response.parsed_body.include? 'inscription'
  end

  def test_dossier_eleve_possede_un_contact_urgence
    dossier_eleve = DossierEleve.first

    ContactUrgence.update(ContactUrgence.first.id, {dossier_eleve_id: dossier_eleve.id, tel_principal: "0123456789"})

    assert dossier_eleve.contact_urgence.tel_principal == "0123456789"
  end

  def test_persistence_du_resp_legal_1
    doc = soumet_formulaire '/famille', params: { lien_de_parente_rl1: "TUTEUR", prenom_rl1: "Philippe", nom_rl1: "Blayo", adresse_rl1: "20 bd Segur", code_postal_rl1: "75007", ville_rl1: "Paris", tel_principal_rl1: "0612345678", tel_secondaire_rl1: "0112345678", email_rl1: "test@gmail.com", profession_rl1: "Retraité cadre, profession interm édiaire", enfants_a_charge_rl1: 3, communique_info_parents_eleves_rl1: 'true'}

    assert_equal 'TUTEUR', doc.css('#lien_de_parente_rl1 option[@selected="selected"]').children.text
    assert_attr 'Philippe', '#prenom_rl1', doc
    assert_attr 'Blayo', '#nom_rl1', doc
    assert_attr '20 bd Segur', '#adresse_rl1', doc
    assert_attr '75007', '#code_postal_rl1', doc
    assert_attr 'Paris', '#ville_rl1', doc
    assert_attr '0612345678', '#tel_principal_rl1', doc
    assert_attr '0112345678', '#tel_secondaire_rl1', doc
    assert_attr 'test@gmail.com', '#email_rl1', doc
    assert_equal 'Retraité cadre, profession interm édiaire', doc.css('#profession_rl1 option[@selected="selected"]').children.text
    assert_attr '3', '#enfants_a_charge_rl1', doc
    assert_equal 'checked', doc.css('#communique_info_parents_eleves_rl1').attr('checked').text
  end

  def test_persistence_du_resp_legal_2
    doc = soumet_formulaire  '/famille', params: { lien_de_parente_rl2: "MERE", prenom_rl2: "Philippe" , nom_rl2: "Blayo", adresse_rl2: "20 bd Segur",code_postal_rl2: "75007", ville_rl2: "Paris", tel_principal_rl2: "0612345678", tel_secondaire_rl2: "0112345678", email_rl2: "test@gmail.com", profession_rl2: "Retraité cadre, profession interm édiaire", communique_info_parents_eleves_rl2: 'true' }

    assert_equal 'MERE', doc.css('#lien_de_parente_rl2 option[@selected="selected"]').children.text
    assert_attr 'Philippe', '#prenom_rl2', doc
    assert_attr 'Blayo', '#nom_rl2', doc
    assert_attr '20 bd Segur', '#adresse_rl2', doc
    assert_attr '75007', '#code_postal_rl2', doc
    assert_attr 'Paris', '#ville_rl2', doc
    assert_attr '0612345678', '#tel_principal_rl2', doc
    assert_attr '0112345678', '#tel_secondaire_rl2', doc
    assert_attr 'test@gmail.com', '#email_rl2', doc
    assert_equal 'Retraité cadre, profession interm édiaire', doc.css('#profession_rl2 option[@selected="selected"]').children.text
    assert_equal 'checked', doc.css('#communique_info_parents_eleves_rl2').attr('checked').text
  end

  def test_persistence_du_contact_urg
    doc = soumet_formulaire '/famille', params: { lien_avec_eleve_urg: "Tuteur", prenom_urg: "Philippe" , nom_urg: "Blayo", tel_principal_urg: "0612345678", tel_secondaire_urg: "0112345678" }

    assert_attr 'Tuteur', '#lien_avec_eleve_urg', doc
    assert_attr 'Philippe', '#prenom_urg', doc
    assert_attr 'Blayo', '#nom_urg', doc
    assert_attr '0612345678', '#tel_principal_urg', doc
    assert_attr '0112345678', '#tel_secondaire_urg', doc
  end

  def test_changement_adresse
    post '/identification', params: { identifiant: '2', annee: '1915', mois: '12', jour: '19'}
    get '/famille'
    doc = Nokogiri::HTML(response.parsed_body)
    donnees = reinjecte_donnees_formulaire_famille doc

    # Pas de changement d'adresse
    donnees['tel_principal_rl1'] = "Changement de numéro"
    doc = soumet_formulaire '/famille', params: donnees

    eleve = Eleve.find_by(identifiant: 2)
    assert eleve.dossier_eleve.resp_legal_1.adresse_inchangee

    # Changement d'adresse
    donnees['adresse_rl1'] = "Nouvelle adresse"
    doc = soumet_formulaire '/famille', params: donnees

    eleve = Eleve.find_by(identifiant: 2)
    assert ! eleve.dossier_eleve.resp_legal_1.adresse_inchangee
  end


  def soumet_formulaire(*arguments_du_post)
    post '/identification', params: { identifiant: '2', annee: '1915', mois: '12', jour: '19'}
    post *arguments_du_post
    get arguments_du_post[0]
    Nokogiri::HTML(response.parsed_body)
  end

  def message_erreur_identification identifiant, date_naissance
    mois_de_l_année = {
      '01' => 'janvier', '02' => 'février', '03' => 'mars', '04' => 'avril',
      '05' => 'mai', '06' => 'juin', '07' => 'juillet', '08' => 'août',
      '09' => 'septembre', '10' => 'octobre', '11' => 'novembre', '12' => 'décembre'
    }
    if identifiant.to_s.empty? || date_naissance.to_s.empty?
      return "Veuillez fournir identifiant et date de naissance"
    end
    annee, mois, jour = normalise(date_naissance).split('-')
    "L'élève a bien comme identifiant #{identifiant} et comme date de naissance le #{jour} #{mois_de_l_année[mois]} #{annee} ?"
  end

  def assert_attr(valeur_attendue, selecteur_css, doc)
    valeur_trouvee = doc.css(selecteur_css).attr('value') ? # c'est un input ?
        doc.css(selecteur_css).attr('value').text # oui
      : doc.css(selecteur_css).text # non, on suppose un textarea
    assert_equal valeur_attendue, valeur_trouvee
  end

  def reinjecte_donnees_formulaire_famille doc
    champs = [:lien_de_parente, :prenom, :nom, :adresse, :code_postal, :ville,
              :tel_principal, :tel_secondaire, :email]

    donnees = {}
    champs.each do |champ|
      ['rl1','rl2'].each do |rl|
        champ_qualifie = "#{champ}_#{rl}"
        selecteur = "\##{champ_qualifie}"
        valeur = doc.css(selecteur).attr('value').text if doc.css(selecteur).attr('value')
        valeur = doc.css(selecteur).text if !doc.css(selecteur).attr('value')
        donnees[champ_qualifie] = valeur
      end
    end
    donnees
  end

  def test_ramène_parent_à_dernière_étape_incomplète
    post '/identification', params: {identifiant: '6', annee: '1970', mois: '01', jour: '01'}
    post '/eleve', params: {Espagnol: true, Latin: true}
    get '/famille'

    post '/identification', params: {identifiant: '6', annee: '1970', mois: '01', jour: '01'}
    follow_redirect!

    doc = Nokogiri::HTML(response.parsed_body)
    assert_equal "Famille : Responsable légal 1", doc.css("body > main > div.col-12 > h2").text
  end

  def test_affichage_des_options_choisis_sur_la_page_validation
    eleve = Eleve.create(identifiant: 'XXX', date_naiss: '1970-01-01', niveau_classe_ant: '3')
    etablissement = Etablissement.create(nom: 'college test')
    dossier_eleve = DossierEleve.create(eleve_id: eleve.id, etablissement_id: etablissement.id)
    eleve.option << Option.create(nom: 'anglais', groupe: 'LV1')
    option_choisie = Option.create(nom: 'grec', groupe: 'LCA')
    demande = Demande.create(option_id: option_choisie.id, eleve_id: eleve.id)
    option_abandonnee = Option.create(nom: 'latin', groupe: 'LCA')
    abandon = Abandon.create(option_id: option_abandonnee.id, eleve_id: eleve.id)

    post '/identification', params: {identifiant: 'xxx', annee: '1970', mois: '01', jour: '01'}
    get '/validation'

    assert response.parsed_body.include? 'anglais'
    assert response.parsed_body.include? "<strong>grec</strong>"
    assert response.parsed_body.include? "<strong>latin</strong>"
  end

  def test_une_famille_remplit_letape_administration
    post '/identification', params: { identifiant: '2', annee: '1915', mois: '12', jour: '19' }
    get '/administration'
    post '/administration', params: { demi_pensionnaire: true, autorise_sortie: true,
      renseignements_medicaux: true, autorise_photo_de_classe: false }
    get '/administration'

    assert response.parsed_body.gsub(/\s/,'').include? "id='demi_pensionnaire' checked".gsub(/\s/,'')
    assert response.parsed_body.gsub(/\s/,'').include? "id='autorise_sortie' checked".gsub(/\s/,'')
    assert response.parsed_body.gsub(/\s/,'').include? "id='renseignements_medicaux' checked".gsub(/\s/,'')
    assert response.parsed_body.gsub(/\s/,'').include? "id='autorise_photo_de_classe' checked".gsub(/\s/,'')
  end

  # le masquage du formulaire de contact se fait en javascript
  def test_html_du_contact_present_dans_page_quand_pas_encore_de_contact
    e = Eleve.create! identifiant: 'XXX', date_naiss: '1915-12-19'
    dossier_eleve = DossierEleve.create! eleve: e, etablissement: Etablissement.first
    RespLegal.create! dossier_eleve: dossier_eleve, email: 'test@test.com', priorite: 1

    post '/identification', params: { identifiant: 'XXX', annee: '1915', mois: '12', jour: '19' }
    get '/famille'

    doc = Nokogiri::HTML(response.parsed_body)
    assert_not_nil doc.css("input#tel_principal_urg").first
  end

  def test_ramene_a_la_dernire_etape_visitee_plutot_que_l_etape_la_plus_avancee
    post '/identification', params: { identifiant: '4', annee: '1970', mois: '01', jour: '01' }
    post '/famille'
    get '/eleve'
    post '/deconnexion'
    post '/identification', params: { identifiant: '4', annee: '1970', mois: '01', jour: '01' }
    follow_redirect!
    assert response.parsed_body.include? html_escape("Identité de l'élève")
  end

  def test_ramene_a_l_etape_confirmation_pour_la_satisfaction
    post '/identification', params: { identifiant: '4', annee: '1970', mois: '01', jour: '01' }
    get '/confirmation'
    post '/satisfaction'
    post '/deconnexion'
    post '/identification', params: { identifiant: '4', annee: '1970', mois: '01', jour: '01' }
    follow_redirect!
    assert response.parsed_body.include? "Vous recevrez prochainement un courriel de confirmation"
  end

  def test_envoyer_un_mail_quand_la_demande_dinscription_est_valide
    post '/identification', params: { identifiant: '4', annee: '1970', mois: '01', jour: '01' }
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

end
