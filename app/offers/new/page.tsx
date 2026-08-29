"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { ArrowLeft, Check, ChevronDown, Search } from "lucide-react";
import Link from "next/link";

const countries = [
  "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antigua and Barbuda", "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan",
  "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bhutan", "Bolivia", "Bosnia and Herzegovina", "Botswana", "Brazil", "Brunei", "Bulgaria", "Burkina Faso", "Burundi",
  "Cabo Verde", "Cambodia", "Cameroon", "Canada", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros", "Congo", "Costa Rica", "Croatia", "Cuba", "Cyprus", "Czechia",
  "Democratic Republic of the Congo", "Denmark", "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Eswatini", "Ethiopia",
  "Fiji", "Finland", "France", "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana",
  "Haiti", "Honduras", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy", "Ivory Coast", "Jamaica", "Japan", "Jordan",
  "Kazakhstan", "Kenya", "Kiribati", "Kuwait", "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg",
  "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Morocco", "Mozambique", "Myanmar",
  "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Niger", "Nigeria", "North Korea", "North Macedonia", "Norway", "Oman", "Pakistan", "Palau", "Palestine", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Poland", "Portugal",
  "Qatar", "Romania", "Russia", "Rwanda", "Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines", "Samoa", "San Marino", "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Korea", "South Sudan", "Spain", "Sri Lanka", "Sudan", "Suriname", "Sweden", "Switzerland", "Syria",
  "Taiwan", "Tajikistan", "Tanzania", "Thailand", "Timor-Leste", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "United States", "Uruguay", "Uzbekistan", "Vanuatu", "Vatican City", "Venezuela", "Vietnam", "Yemen", "Zambia", "Zimbabwe",
];

const commercialTerms = [
  "FOB", "CIF", "CFR", "EXW", "FCA", "DDP", "Payment in Advance", "Letter of Credit", "Negotiable",
];

const documentationOptions = [
  "Commercial Invoice", "Packing List", "Certificate of Origin", "Certificate of Analysis", "Inspection Certificate", "Technical Datasheet", "CE / Conformity", "Other",
];

const regionToCountry: Record<string, string> = {
  KR: "South Korea", MA: "Morocco", FR: "France", US: "United States", CA: "Canada", GB: "United Kingdom", DE: "Germany", ES: "Spain", IT: "Italy", BE: "Belgium", NL: "Netherlands", CH: "Switzerland", AE: "United Arab Emirates", SA: "Saudi Arabia", TR: "Turkey", JP: "Japan", CN: "China", IN: "India", AU: "Australia", BR: "Brazil",
};

function CountrySelect({
  id,
  name,
  label,
  value,
  onChange,
  placeholder,
  allowInternational = false,
}: {
  id: string;
  name: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  allowInternational?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");

  const filteredCountries = useMemo(() => {
    const q = query.trim().toLowerCase();
    return countries.filter((country) => country.toLowerCase().includes(q));
  }, [query]);

  function choose(country: string) {
    onChange(country);
    setQuery("");
    setOpen(false);
  }

  return (
    <div className="relative">
      <label className="text-sm font-bold text-slate-800" htmlFor={id}>{label}</label>
      <input type="hidden" id={id} name={name} value={value} readOnly />
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen((current) => !current)}
        className="mt-2 flex w-full items-center justify-between rounded-xl border border-slate-200 bg-white px-4 py-3 text-left text-sm"
      >
        <span className={value ? "text-slate-800" : "text-slate-400"}>{value || placeholder}</span>
        <ChevronDown size={17} className="text-slate-400" />
      </button>

      {open && (
        <div className="absolute z-30 mt-2 w-full overflow-hidden rounded-xl border border-slate-200 bg-white shadow-xl">
          <div className="border-b border-slate-100 p-2">
            <div className="flex items-center gap-2 rounded-lg border border-slate-200 px-3">
              <Search size={15} className="text-slate-400" />
              <input
                autoFocus
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search country..."
                className="w-full border-0 px-1 py-2.5 text-sm outline-none"
              />
            </div>
          </div>
          <div className="max-h-64 overflow-y-auto p-1" role="listbox">
            {allowInternational && (
              <button
                type="button"
                onClick={() => choose("International Market")}
                className={`w-full rounded-lg px-3 py-2.5 text-left text-sm font-bold hover:bg-orange-50 ${value === "International Market" ? "bg-orange-50 text-orange-600" : "text-slate-700"}`}
              >
                International Market
              </button>
            )}
            {filteredCountries.map((country) => (
              <button
                type="button"
                key={country}
                onClick={() => choose(country)}
                className={`w-full rounded-lg px-3 py-2.5 text-left text-sm hover:bg-orange-50 ${value === country ? "bg-orange-50 font-bold text-orange-600" : "text-slate-700"}`}
              >
                {country}
              </button>
            ))}
            {filteredCountries.length === 0 && <p className="px-3 py-4 text-sm text-slate-400">No country found.</p>}
          </div>
        </div>
      )}
    </div>
  );
}

export default function NewOfferPage() {
  const [selectedTerms, setSelectedTerms] = useState<string[]>([]);
  const [selectedDocs, setSelectedDocs] = useState<string[]>([]);
  const [commercialOther, setCommercialOther] = useState("");
  const [documentationOther, setDocumentationOther] = useState("");
  const [market, setMarket] = useState("");
  const [geography, setGeography] = useState("");

  useEffect(() => {
    const region = new Intl.Locale(navigator.language).region;
    setGeography(regionToCountry[region || ""] || "South Korea");
  }, []);

  function toggleTerm(term: string) {
    setSelectedTerms((current) => current.includes(term) ? current.filter((item) => item !== term) : [...current, term]);
  }

  function toggleDoc(doc: string) {
    setSelectedDocs((current) => current.includes(doc) ? current.filter((item) => item !== doc) : [...current, doc]);
  }

  function submitForm(event: FormEvent<HTMLFormElement>) {
    if (!market || !geography) {
      event.preventDefault();
      return;
    }
  }

  const commercialValue = [...selectedTerms, ...(commercialOther.trim() ? [`Other: ${commercialOther.trim()}`] : [])].join(", ");
  const documentationValue = [...selectedDocs.filter((doc) => doc !== "Other"), ...(documentationOther.trim() ? [`Other: ${documentationOther.trim()}`] : [])].join(", ");

  return (
    <main className="min-h-screen bg-slate-50 px-5 py-10 sm:px-8">
      <div className="mx-auto max-w-3xl">
        <Link href="/" className="inline-flex items-center gap-2 text-sm font-bold text-orange-600"><ArrowLeft size={16} /> Back</Link>
        <section className="mt-6 rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-orange-600">QimaTrade · Supplier</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Create a new offer</h1>
          <p className="mt-3 text-sm leading-6 text-slate-500">Start a supplier offer independently. Product classification and buyer matching come later.</p>

          <form action="/api/offers" method="post" onSubmit={submitForm} className="mt-8 space-y-5">
            <div>
              <label className="text-sm font-bold text-slate-800" htmlFor="name">Offer name</label>
              <input id="name" name="name" required placeholder="e.g. Used CNC Vertical Machining Center" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" />
            </div>

            <div className="grid gap-4 sm:grid-cols-3">
              <div><label className="text-sm font-bold" htmlFor="quantity">Quantity</label><input id="quantity" name="quantity" required type="number" min="0.000001" step="any" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div>
              <div><label className="text-sm font-bold" htmlFor="price">Price</label><input id="price" name="price" type="number" min="0" step="any" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" /></div>
              <div><label className="text-sm font-bold" htmlFor="currency">Currency</label><select id="currency" name="currency" defaultValue="USD" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm"><option>USD</option><option>EUR</option><option>KRW</option><option>MAD</option><option>CNY</option></select></div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <CountrySelect id="market" name="market" label="Target market" value={market} onChange={setMarket} placeholder="Select a target market" allowInternational />
              <CountrySelect id="geography" name="geography" label="Supplier geography" value={geography} onChange={setGeography} placeholder="Select supplier geography" />
            </div>

            <div>
              <label className="text-sm font-bold text-slate-800">Commercial terms</label>
              <input name="conditions" type="hidden" value={commercialValue} readOnly />
              <div className="mt-2 flex flex-wrap gap-2 rounded-xl border border-slate-200 p-3">
                {commercialTerms.map((term) => {
                  const selected = selectedTerms.includes(term);
                  return <button key={term} type="button" aria-pressed={selected} onClick={() => toggleTerm(term)} className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-bold transition-colors ${selected ? "border-orange-500 bg-orange-500 text-white" : "border-slate-200 bg-white text-slate-700 hover:border-orange-300 hover:text-orange-600"}`}>{selected && <Check size={14} strokeWidth={3} />}{term}</button>;
                })}
                <button type="button" aria-pressed={Boolean(commercialOther)} onClick={() => document.getElementById("commercial-other")?.focus()} className={`rounded-lg border px-3 py-2 text-sm font-bold ${commercialOther ? "border-orange-500 bg-orange-500 text-white" : "border-slate-200 bg-white text-slate-700 hover:border-orange-300 hover:text-orange-600"}`}>Other</button>
              </div>
              <input id="commercial-other" value={commercialOther} onChange={(event) => setCommercialOther(event.target.value)} placeholder="Other commercial term..." className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" />
            </div>

            <div>
              <label className="text-sm font-bold text-slate-800">Documentation available</label>
              <input name="documentation" type="hidden" value={documentationValue} readOnly />
              <div className="mt-2 flex flex-wrap gap-2 rounded-xl border border-slate-200 p-3">
                {documentationOptions.map((doc) => {
                  const selected = selectedDocs.includes(doc);
                  return <button key={doc} type="button" aria-pressed={selected} onClick={() => toggleDoc(doc)} className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-bold transition-colors ${selected ? "border-orange-500 bg-orange-500 text-white" : "border-slate-200 bg-white text-slate-700 hover:border-orange-300 hover:text-orange-600"}`}>{selected && <Check size={14} strokeWidth={3} />}{doc}</button>;
                })}
              </div>
              {selectedDocs.includes("Other") && <input value={documentationOther} onChange={(event) => setDocumentationOther(event.target.value)} placeholder="Other documentation..." className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 text-sm" />}
            </div>

            <button type="submit" disabled={!market || !geography} className="rounded-xl bg-orange-500 px-6 py-3 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-50">Create offer</button>
          </form>
        </section>
      </div>
    </main>
  );
}
