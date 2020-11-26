# frozen_string_literal: true

describe 'Ridgepole::Client#diff -> migrate' do
  let(:actual_dsl) do
    erbh(<<-ERB)
      create_table "employees", force: :cascade, comment: "old comment" do |t|
        t.date   "birth_date", null: false
        t.string "first_name", limit: 14, null: false
        t.string "last_name", limit: 16, null: false
        t.string "gender", limit: 1, null: false
        t.date   "hire_date", null: false
      end
    ERB
  end

  let(:expected_dsl) do
    erbh(<<-ERB)
      create_table "employees", force: :cascade, comment: "new comment" do |t|
        t.date   "birth_date", null: false
        t.string "first_name", limit: 14, null: false
        t.string "last_name", limit: 16, null: false
        t.string "gender", limit: 1, null: false
        t.date   "hire_date", null: false
      end
    ERB
  end

  before { subject.diff(actual_dsl).migrate }

  context 'when ignore_table_comment option is false' do
    subject { client }

    it {
      expect(Ridgepole::Logger.instance).to receive(:warn).with(<<-MSG)
[WARNING] Table option changes are ignored on `employees`.
  from: {:comment=>"old comment"}
    to: {:comment=>"new comment"}
      MSG
      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_falsey
      expect(subject.dump).to match_ruby actual_dsl
      delta.migrate
      expect(subject.dump).to match_ruby actual_dsl
    }
  end

  context 'when ignore_table_comment option is true' do
    subject { client(ignore_table_comment: true) }

    it {
      expect(Ridgepole::Logger.instance).to_not receive(:warn)
      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_falsey
      expect(subject.dump).to match_ruby actual_dsl
      delta.migrate
      expect(subject.dump).to match_ruby actual_dsl
    }
  end

  context 'when mysql_change_table_comment option is true' do
    subject { client(mysql_change_table_comment: true) }

    it {
      expect(Ridgepole::Logger.instance).to_not receive(:warn)
      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_truthy
      expect(subject.dump).to match_ruby actual_dsl
      delta.migrate
      expect(subject.dump).to match_ruby expected_dsl
    }
  end
end

describe 'Ridgepole::Client#diff -> migrate' do
  partitions = []
  partitions << "PARTITION p201610 VALUES LESS THAN ('2016-10-01') ENGINE = InnoDB"
  partitions << "PARTITION p201611 VALUES LESS THAN ('2016-11-01') ENGINE = InnoDB"
  partitioning_sql = "/*!50500 PARTITION BY RANGE COLUMNS(created_at)\\n(#{partitions.join(',\n ')}) */"

  let(:dsl) do
    erbh(<<-ERB)
      create_table "histories", primary_key: ["id", "created_at"], force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4\\n#{partitioning_sql}" do |t|
        t.bigint   "id", null: false, unsigned: true, auto_increment: true
        t.bigint   "user_id", default: 0, null: false, unsigned: true
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
      end
    ERB
  end

  before { subject.diff(dsl).migrate }

  context 'when partition options' do
    subject { client(dump_without_table_options: false) }

    it {
      expect(Ridgepole::Logger.instance).not_to receive(:warn).with(<<-MSG)
[WARNING] Table option changes are ignored on `histories`.
  from: {:primary_key=>["id", "created_at"], :options=>"ENGINE=InnoDB DEFAULT CHARSET=utf8mb4\\n/*!50500 PARTITION BY RANGE  COLUMNS(created_at)\\n(PARTITION p201610 VALUES LESS THAN ('2016-10-01') ENGINE = InnoDB,\\n PARTITION p201611 VALUES LESS THAN ('2016-11-01') ENGINE = InnoDB) */"}
    to: {:primary_key=>["id", "created_at"], :options=>"ENGINE=InnoDB DEFAULT CHARSET=utf8mb4\\n/*!50500 PARTITION BY RANGE COLUMNS(created_at)\\n(PARTITION p201610 VALUES LESS THAN ('2016-10-01') ENGINE = InnoDB,\\n PARTITION p201611 VALUES LESS THAN ('2016-11-01') ENGINE = InnoDB) */"}
      MSG
      delta = subject.diff(dsl)
      delta.migrate
      expect(subject.dump).to match_ruby dsl
    }
  end
end
