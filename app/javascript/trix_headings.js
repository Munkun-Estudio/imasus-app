const configureTrixHeadings = () => {
  const Trix = window.Trix
  if (!Trix) return

  Trix.config.blockAttributes.heading2 ||= {
    tagName: "h2",
    terminal: true,
    breakOnReturn: true,
    group: false
  }

  Trix.config.blockAttributes.heading3 ||= {
    tagName: "h3",
    terminal: true,
    breakOnReturn: true,
    group: false
  }

  Trix.config.lang.heading2 ||= "Heading 2"
  Trix.config.lang.heading3 ||= "Heading 3"
}

const addHeadingButtons = (toolbar) => {
  const blockTools = toolbar.querySelector("[data-trix-button-group='block-tools']")
  if (!blockTools || blockTools.querySelector("[data-trix-attribute='heading2']")) return

  const heading1 = blockTools.querySelector("[data-trix-attribute='heading1']")
  if (heading1) {
    heading1.textContent = "H1"
    heading1.classList.remove("trix-button--icon", "trix-button--icon-heading-1")
    heading1.classList.add("trix-button--text")
  }

  const heading2 = document.createElement("button")
  heading2.type = "button"
  heading2.className = "trix-button trix-button--text"
  heading2.dataset.trixAttribute = "heading2"
  heading2.title = window.Trix.config.lang.heading2
  heading2.tabIndex = -1
  heading2.textContent = "H2"

  const heading3 = document.createElement("button")
  heading3.type = "button"
  heading3.className = "trix-button trix-button--text"
  heading3.dataset.trixAttribute = "heading3"
  heading3.title = window.Trix.config.lang.heading3
  heading3.tabIndex = -1
  heading3.textContent = "H3"

  heading1?.after(heading2, heading3)
}

configureTrixHeadings()

document.addEventListener("trix-before-initialize", configureTrixHeadings)

document.addEventListener("trix-initialize", (event) => {
  const toolbar = event.target.toolbarElement
  if (toolbar) addHeadingButtons(toolbar)
})
