from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional

from app.core import deps
from app.models import crm as m
from app.schemas import crm as s

router = APIRouter()


# Clients
@router.post("/clientes", response_model=s.ClientRead)
def create_client(payload: s.ClientCreate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    # scoping: unique por (company_id, nit)
    company_id = current.company_id if current.role != "super_admin" else current.company_id
    exists = db.query(m.Client).filter(m.Client.nit == payload.nit, m.Client.company_id == company_id).one_or_none()
    if exists:
        raise HTTPException(status_code=409, detail="Cliente con NIT ya existe")
    client = m.Client(**payload.dict())
    client.company_id = company_id
    client.created_by_user_id = current.id
    db.add(client)
    db.commit()
    db.refresh(client)
    return client


@router.get("/clientes", response_model=List[s.ClientRead])
def list_clients(q: Optional[str] = None, page: int = 1, per_page: int = 20, company_id: Optional[int] = None, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    query = db.query(m.Client)
    # scoping: super_admin puede pedir company_id; otros, su propia empresa
    if current.role == "super_admin" and company_id is not None:
        query = query.filter(m.Client.company_id == company_id)
    elif current.role != "super_admin":
        query = query.filter(m.Client.company_id == current.company_id)
    if q:
        like = f"%{q}%"
        query = query.filter((m.Client.razon_social.ilike(like)) | (m.Client.nit.ilike(like)))
    return query.order_by(m.Client.razon_social).offset((page-1)*per_page).limit(per_page).all()


@router.patch("/clientes/{client_id}", response_model=s.ClientRead)
def update_client(client_id: int, payload: s.ClientUpdate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    client = db.query(m.Client).get(client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    if current.role != "super_admin" and client.company_id != current.company_id:
        raise HTTPException(status_code=403, detail="No permitido")
    for k, v in payload.dict(exclude_unset=True).items():
        setattr(client, k, v)
    client.updated_by_user_id = current.id
    db.commit()
    db.refresh(client)
    return client


@router.get("/clientes/{client_id}/contactos", response_model=List[s.ClientContactRead])
def list_client_contacts(client_id: int, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    client = db.query(m.Client).get(client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    if current.role != "super_admin" and client.company_id != current.company_id:
        raise HTTPException(status_code=403, detail="No permitido")
    rows = db.query(m.ClientContact).filter(m.ClientContact.client_id == client_id).order_by(m.ClientContact.id.desc()).all()
    return rows


@router.post("/clientes/{client_id}/contactos", response_model=s.ClientContactRead)
def create_client_contact(client_id: int, payload: s.ClientContactCreate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    client = db.query(m.Client).get(client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    if current.role != "super_admin" and client.company_id != current.company_id:
        raise HTTPException(status_code=403, detail="No permitido")
    c = m.ClientContact(client_id=client_id, nombre=payload.nombre, cargo=payload.cargo, email=payload.email, telefono=payload.telefono, created_by_user_id=current.id)
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


@router.delete("/clientes/{client_id}")
def delete_client(client_id: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    client = db.query(m.Client).get(client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    db.delete(client)
    db.commit()
    return {"ok": True}


# Leads
@router.post("/leads", response_model=s.LeadRead)
def create_lead(payload: s.LeadCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    lead = m.Lead(**payload.dict())
    db.add(lead)
    db.commit()
    db.refresh(lead)
    return lead


@router.get("/leads", response_model=List[s.LeadRead])
def list_leads(estado: Optional[str] = None, q: Optional[str] = None, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    query = db.query(m.Lead)
    if estado:
        query = query.filter(m.Lead.estado == estado)
    # búsqueda simple por notas
    if q:
        like = f"%{q}%"
        query = query.filter(m.Lead.notas.ilike(like))
    return query.order_by(m.Lead.id.desc()).all()


@router.patch("/leads/{lead_id}", response_model=s.LeadRead)
def update_lead(lead_id: int, payload: s.LeadUpdate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    lead = db.query(m.Lead).get(lead_id)
    if not lead:
        raise HTTPException(status_code=404, detail="Lead no encontrado")
    for k, v in payload.dict(exclude_unset=True).items():
        setattr(lead, k, v)
    db.commit()
    db.refresh(lead)
    return lead


@router.delete("/leads/{lead_id}")
def delete_lead(lead_id: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    lead = db.query(m.Lead).get(lead_id)
    if not lead:
        raise HTTPException(status_code=404, detail="Lead no encontrado")
    db.delete(lead)
    db.commit()
    return {"ok": True}


# Opportunities
@router.post("/oportunidades", response_model=s.OpportunityRead)
def create_opportunity(payload: s.OpportunityCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    if not db.query(m.Lead).get(payload.lead_id):
        raise HTTPException(status_code=400, detail="Lead inválido")
    opp = m.Opportunity(**payload.dict())
    db.add(opp)
    db.commit()
    db.refresh(opp)
    return opp


@router.get("/oportunidades", response_model=List[s.OpportunityRead])
def list_opportunities(etapa: Optional[str] = None, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    query = db.query(m.Opportunity)
    if etapa:
        query = query.filter(m.Opportunity.etapa == etapa)
    return query.order_by(m.Opportunity.id.desc()).all()


@router.patch("/oportunidades/{opp_id}", response_model=s.OpportunityRead)
def update_opportunity(opp_id: int, payload: s.OpportunityUpdate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    opp = db.query(m.Opportunity).get(opp_id)
    if not opp:
        raise HTTPException(status_code=404, detail="Oportunidad no encontrada")
    for k, v in payload.dict(exclude_unset=True).items():
        setattr(opp, k, v)
    db.commit()
    db.refresh(opp)
    return opp


@router.delete("/oportunidades/{opp_id}")
def delete_opportunity(opp_id: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    opp = db.query(m.Opportunity).get(opp_id)
    if not opp:
        raise HTTPException(status_code=404, detail="Oportunidad no encontrada")
    db.delete(opp)
    db.commit()
    return {"ok": True}





