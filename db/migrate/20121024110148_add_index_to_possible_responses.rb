class AddIndexToPossibleResponses < ActiveRecord::Migration
  def change
    add_index :possible_responses, [:question_id, :keypad, :possible_response_order], name: :index_possible_responses_question_keypad_possible_response_order
  end
end
