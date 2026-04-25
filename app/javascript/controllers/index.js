// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import PublicationWizardController from "controllers/publication_wizard_controller"

application.register("publication-wizard", PublicationWizardController)
eagerLoadControllersFrom("controllers", application)
