class AddEmbeddingToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :embedding, :vector, limit: 1536
  end
end
