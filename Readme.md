# FrontEnd
A Rails 3.1 engine which provides Javascript Libraries and Stylesheets for rapidly prototyping advanced frontends.

## Javascript libraries
- jQuery
- jQuery UI
- Backbone
- Backbone.localStorage
- BackRub
- Handlebars.js
- Backbone.relational

## Stylesheets
- Normaliser.css
- Twitter Bootstrap (in SCSS)
- Compass

## Generators
We also include generators for Backbone Models, Views, Routers and a Backbone style scaffold, as well as installation generators.

# Installation
In your Gemfile:

		gem 'frontend'

Automatic install of everything:

		rails g frontend:install

Limited install options:

		rails g frontend:bootstrap
		rails g frontend:backbone
		rails g frontend:backbone:relational
		rails g frontend:backbone:localstorage

# Contributing
- Fork it
- Commit
- Test
- Issue pull request
- Grab a beer

# Authors
- Ivan Vanderbyl