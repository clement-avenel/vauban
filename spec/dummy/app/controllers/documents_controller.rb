# frozen_string_literal: true

class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  # GET /documents
  def index
    # Use Vauban's scoping to get only documents the current user can view
    @documents = Vauban.accessible_by(current_user, :view, Document)
      .includes(:owner, :collaborators)
      .order(created_at: :desc)
    
    # Show all documents for demo purposes (with permission indicators)
    @all_documents = Document.includes(:owner, :collaborators).order(created_at: :desc)
  end

  # GET /documents/:id
  def show
    # Authorize! raises Vauban::Unauthorized if user cannot view
    authorize! :view, @document
  end

  # GET /documents/new
  def new
    @document = Document.new
  end

  # POST /documents
  def create
    @document = Document.new(document_params)
    @document.owner = current_user

    if @document.save
      redirect_to @document, notice: "Document was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /documents/:id/edit
  def edit
    # Authorize! raises Vauban::Unauthorized if user cannot edit
    authorize! :edit, @document
  end

  # PATCH/PUT /documents/:id
  def update
    # Authorize! raises Vauban::Unauthorized if user cannot edit
    authorize! :edit, @document

    if @document.update(document_params)
      redirect_to @document, notice: "Document was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /documents/:id
  def destroy
    # Authorize! raises Vauban::Unauthorized if user cannot delete
    authorize! :delete, @document

    @document.destroy
    redirect_to documents_path, notice: "Document was successfully deleted."
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :content, :public, :archived)
  end
end
