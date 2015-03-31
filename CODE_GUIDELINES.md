Some guidelines to keep the code clean and consistent.

## Spacing

Tabs as spaces. Tab size 2. No hard line-wrap limit but prefer multiple lines over single long lines (ie >80ish characters).

## ActiveRecord models

### Scopes

Define w/ stabby lambdas eg `scope :clever, -> { where('smart > ?', 5) }`.

## Testing

### Forbidden gems

- rspec-activemodel-mocks