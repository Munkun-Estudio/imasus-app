# Admin workshop emails

## What

Add a lightweight admin-only email composer for workshop communications. An
admin can open a workshop-scoped screen, choose whether the recipients are
participants, facilitators, or both for that workshop, write a subject and
HTML body, preview the email, send a test email to themselves, and then send
the message manually. The intended use is operational follow-ups and workshop
news, not a general CRM or newsletter platform.

## Why

The app already sends transactional emails for invitations and password
recovery, but staff have no in-product way to send a clean workshop follow-up
or news update to a specific workshop cohort. Right now that work has to
happen outside the app, which means the workshop audience already curated in
IMASUS is not reusable for communication. This spec adds the smallest useful
communications surface without turning the product into a campaign tool.

## Acceptance Criteria

### Product shape

- [ ] The sending surface is admin-only. Facilitators cannot access the
      composer or trigger sends.
- [ ] Emails are always scoped to one workshop. There is no "all workshops"
      or cross-workshop audience in this spec.
- [ ] Sending is manual only. There is no scheduling, queue management UI, or
      recurring automation.
- [ ] The feature is positioned as workshop communications for follow-ups and
      news, not as a marketing/newsletter module.

### Recipient selection

- [ ] On the composer page, the admin must choose exactly one workshop and one
      recipient group: participants, facilitators, or both.
- [ ] Recipients are derived from the existing workshop associations in the
      database. No manual email entry field exists in this spec.
- [ ] The UI shows a recipient count before send.
- [ ] Users without an email address are excluded automatically.
- [ ] If the resulting audience is empty, send is blocked with a clear error.

### Composer

- [ ] Admin can enter a subject line and HTML body.
- [ ] Admin may optionally attach one PDF file to the email.
- [ ] The body is authored in a rich-text editor consistent with the app's
      existing editor stack, or a constrained HTML-capable surface if that is
      materially simpler to implement.
- [ ] The UI includes a preview step or preview mode showing the rendered
      email before send.
- [ ] The UI includes a "send test to myself" action that delivers the email
      only to the current admin user's email address.
- [ ] The send action requires an explicit confirmation step to reduce
      accidental broadcasts.

### Delivery behavior

- [ ] Sending creates one email per recipient through the app mailer layer.
- [ ] The delivered email includes an HTML part and a plain-text part.
- [ ] If a PDF attachment is present, it is included in both test sends and
      real sends.
- [ ] The plain-text part may be generated from the HTML body in this spec; it
      does not require separate authoring.
- [ ] Subject and body are frozen at send time for that delivery batch.
- [ ] After a successful send, the admin sees a summary flash with the
      workshop name, audience type, and recipient count.

### Data and traceability

- [ ] Each manual send is persisted as a record so admins can see what was
      sent later without reading SMTP logs.
- [ ] The persisted record stores at least: sender, workshop, audience type,
      subject, HTML body snapshot, recipient count, and sent timestamp.
- [ ] If a PDF attachment is present, the send record retains it so admins can
      see that it was included later.
- [ ] A workshop-level or admin-level index page lists previous sends newest
      first.
- [ ] This spec does not require per-recipient delivery/open/click analytics.

### Routes and auth

- [ ] Authenticated non-admin users are blocked from all admin workshop email
      routes with the existing access-denied behavior.
- [ ] There is a clear path from an admin-reachable workshop/admin surface to
      open the composer.
- [ ] Suggested route shape:

```ruby
namespace :admin do
  resources :workshops, only: [] do
    resources :emails, only: [:index, :new, :create], controller: "workshop_emails" do
      post :send_test, on: :collection
    end
  end
end
```

### I18n and content constraints

- [ ] All new UI copy, mailer strings, and flash messages go through `t(...)`
      with keys in `en`, `es`, `it`, and `el`.
- [ ] The feature does not add unsubscribe management, preference centers, or
      marketing-compliance flows.
- [ ] The feature does not send to arbitrary uploaded lists or free-typed
      external contacts.

## Out of Scope

- Facilitator-authored outbound email.
- Cross-workshop or global recipient groups.
- Scheduled sending, drafts, recurring campaigns, or automations.
- Template library, saved blocks, or branded template builder.
- Audience segmentation by participation status, project activity, country,
  role within project, or any other derived rule.
- Multiple attachments or non-PDF attachments.
- A/B testing, open tracking, click tracking, or unsubscribe analytics.
- Reply handling / shared inbox workflows.
- General-purpose newsletter infrastructure for the public website.

## Notes

- This spec intentionally expands the current "transactional emails only"
  boundary in project memory, but only by a narrow operational slice:
  admin-authored workshop follow-ups and news.
- Keep the UI calm and operational. This should feel like a staff utility
  inside IMASUS, not like a CRM campaign dashboard.
