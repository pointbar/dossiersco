Rails.application.routes.draw do
  root to: 'accueil#index'

  resource  :dossier_affelnet, only: [:create] do
    post :traiter
  end

  resource  :configuration,        only: [:show]
  resources :options_pedagogiques, except: [:show]
  namespace :configuration do
    resources :mef
    resources :etablissements
    resources :agents do
      member do
        post 'changer_etablissement'
      end
    end
  end
  resources :pieces_jointes,       only: [:create, :update]
  resources :agent_pieces_jointes, only: [:create, :update]
  resources :tache_imports, only: [:create]

  post '/identification', to: 'accueil#identification'
  get '/accueil', to: 'accueil#accueil'

  get '/eleve', to: 'accueil#get_eleve'
  post '/eleve', to: 'accueil#post_eleve'

  get '/famille', to: 'accueil#get_famille'
  post '/famille', to: 'accueil#post_famille'

  get '/validation', to: 'accueil#validation'
  post '/validation', to: 'accueil#post_validation'

  get '/administration', to: 'accueil#administration'
  post '/administration', to: 'accueil#post_administration'

  post '/deconnexion', to: 'accueil#deconnexion'

  get '/confirmation', to: 'accueil#confirmation'

  post '/satisfaction', to: 'accueil#satisfaction'
  post '/commentaire', to: 'accueil#commentaire'

  get '/pieces_a_joindre', to: 'accueil#pieces_a_joindre'
  post '/pieces_a_joindre', to: 'accueil#post_pieces_a_joindre'

  get '/piece/:dossier_eleve/:code_piece/:s3_key', to: 'accueil#piece'

  get '/deconnexion', to: 'accueil#deconnexion'

  get '/stats', to: 'accueil#stats'

  get '/agent', to: 'inscriptions#agent'
  post '/agent', to: 'inscriptions#post_agent'

  get '/agent/liste_des_eleves', to: 'inscriptions#liste_des_eleves'

  get '/agent/import_siecle', to: 'inscriptions#new_import_siecle'

  get '/api/traiter_imports', to: 'inscriptions#declenche_traiter_imports'

  post '/agent/change_etat_fichier', to: 'inscriptions#change_etat_fichier'

  get '/agent/eleve/:identifiant', to: 'inscriptions#eleve'

  get '/agent/piece_attendues', to: 'inscriptions#pieces_attendues'
  post '/agent/piece_attendues', to: 'inscriptions#post_pieces_attendues'

  post '/agent/pdf', to: 'inscriptions#post_pdf'

  post '/agent/valider_inscription', to: 'inscriptions#valider_inscription'

  post '/agent/eleve_sortant', to: 'inscriptions#eleve_sortant'

  post '/agent/contacter_une_famille', to: 'inscriptions#contacter_une_famille'

  post '/agent/relance_emails', to: 'inscriptions#relance_emails'

  get '/agent/fusionne_modele/:modele_id/eleve/:identifiant', to: 'inscriptions#fusionne_modele'

  post '/agent/valider_plusieurs_dossiers', to: 'inscriptions#valider_plusieurs_dossiers'

  get '/agent/options', to: 'inscriptions#options'

  get '/agent/convocations', to: 'inscriptions#convocations'

  get '/agent/deconnexion', to: 'inscriptions#deconnexion'

  get '/agent/tableau_de_bord', to: 'inscriptions#tableau_de_bord'

  post '/agent/pieces_jointes_eleve/:identifiant', to: 'inscriptions#post_pieces_jointes_eleve'

  get '/agent/export', to: 'inscriptions#export'

  post '/agent/supprime_option', to: 'inscriptions#supprime_option'

  post '/agent/supprime_piece_attendue', to: 'inscriptions#supprime_piece_attendue'

  get '/agent/pdf', to: 'inscriptions#pdf'

  get '/agent/relance', to: 'inscriptions#relance'
  post '/agent/relance_sms', to: 'inscriptions#relance_sms'

  get '/redirection_erreur', to: 'pages#redirection_erreur'

  mount LetterOpenerWeb::Engine, at: "/letter_opener" unless ENV['laisser_partir_les_emails']
end
