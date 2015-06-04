class CreateTeachers < ActiveRecord::Migration
  def change
    create_table :teachers do |t|
      t.string :first_name
      t.string :last_name
      t.integer :age
      t.integer :gender
      t.string :mobile

      t.timestamps null: false
    end
  end
end
