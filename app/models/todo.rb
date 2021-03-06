class Todo < ActiveRecord::Base
  include Sortable

  ASSIGNED          = 1
  MENTIONED         = 2
  BUILD_FAILED      = 3
  MARKED            = 4
  APPROVAL_REQUIRED = 5 # This is an EE-only feature

  ACTION_NAMES = {
    ASSIGNED => :assigned,
    MENTIONED => :mentioned,
    BUILD_FAILED => :build_failed,
    MARKED => :marked,
    APPROVAL_REQUIRED => :approval_required
  }

  belongs_to :author, class_name: "User"
  belongs_to :note
  belongs_to :project
  belongs_to :target, polymorphic: true, touch: true
  belongs_to :user

  delegate :name, :email, to: :author, prefix: true, allow_nil: true

  validates :action, :project, :target_type, :user, presence: true
  validates :target_id, presence: true, unless: :for_commit?
  validates :commit_id, presence: true, if: :for_commit?

  default_scope { reorder(id: :desc) }

  scope :pending, -> { with_state(:pending) }
  scope :done, -> { with_state(:done) }

  state_machine :state, initial: :pending do
    event :done do
      transition [:pending] => :done
    end

    state :pending
    state :done
  end

  after_save :keep_around_commit

  class << self
    def sort(method)
      method == "priority" ? order_by_labels_priority : order_by(method)
    end

    # Order by priority depending on which issue/merge request the Todo belongs to
    # Todos with highest priority first then oldest todos
    # Need to order by created_at last because of differences on Mysql and Postgres when joining by type "Merge_request/Issue"
    def order_by_labels_priority
      highest_priority = highest_label_priority(["Issue", "MergeRequest"], "todos.target_id").to_sql

      select("#{table_name}.*, (#{highest_priority}) AS highest_priority").
        order(Gitlab::Database.nulls_last_order('highest_priority', 'ASC')).
        order('todos.created_at')
    end
  end

  def build_failed?
    action == BUILD_FAILED
  end

  def action_name
    ACTION_NAMES[action]
  end

  def body
    if note.present?
      note.note
    else
      target.title
    end
  end

  def for_commit?
    target_type == "Commit"
  end

  # override to return commits, which are not active record
  def target
    if for_commit?
      project.commit(commit_id) rescue nil
    else
      super
    end
  end

  def target_reference
    if for_commit?
      target.short_id
    else
      target.to_reference
    end
  end

  private

  def keep_around_commit
    project.repository.keep_around(self.commit_id)
  end
end
