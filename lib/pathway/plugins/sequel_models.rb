require 'sequel/model'

module Pathway
  module Plugins
    module SequelModels
      module DSLMethods
        def transaction(&bl)
          sequence(-> seq, _ {
            db.transaction(savepoint: true) do
              raise Sequel::Rollback if seq.call.failure?
            end
          }, &bl)
        end

        def after_commit(&bl)
          sequence(-> seq, _ {
            db.after_commit do
              seq.call
            end
          }, &bl)
        end
      end

      module ClassMethods
        attr_accessor :model_class, :search_field

        def model(model_class, search_by: model_class.primary_key, set_result_key: true)
          self.model_class  = model_class
          self.search_field = search_by
          self.result_key   = Inflecto.underscore(model_class.name.split('::').last).to_sym if set_result_key
        end

        def inherited(subclass)
          super
          subclass.model_class  = model_class
          subclass.search_field = search_field
        end
      end

      module InstanceMethods
        extend Forwardable
        delegate %i[model_class search_field] => 'self.class'
        delegate :db => :model_class

        def fetch_model(state, from: model_class, using: search_field, search_by: search_field, to: result_key, overwrite: false)
          if state[to].nil? || overwrite
            find_model_with(state[:input][using], from, search_by)
              .then { |model| state.update(to => model) }
          else
            state
          end
        end

        def build_model_with(params)
          wrap(model_class.new(params))
        end

        def find_model_with(key, dataset = model_class, column = search_field)
          wrap_if_present(dataset.first(column => key))
        end
      end

      def self.apply(operation, model: nil, **args)
        operation.model(model, args) if model
      end
    end
  end
end
